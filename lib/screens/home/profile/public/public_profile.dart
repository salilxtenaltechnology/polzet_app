// ignore_for_file: deprecated_member_use, unused_local_variable, unused_field, unused_element
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:feather_icons/feather_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:glass/glass.dart';
import 'package:polzet_app/screens/home/profile/public/chase/public_chase_list.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../api/api_config.dart';
import '../../../../api/services/api_service.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_images.dart';
import '../../../../languages/l10n/generated/app_localizations.dart';
import '../../../../mixin/utility_mixins.dart';
import '../../../../models/public/public_profile_model.dart';
import '../../../../models/public/things/public_things_card.dart';
import '../../../../provider/private_chat_provider.dart';
import '../../../../provider/public_profile_provider.dart';
import '../../../../provider/user_provider.dart';
import '../../../../widgets/base64/image_convert.dart';
import '../../../../widgets/simmer/public_profile_simmer.dart';
import '../../message/chat/private/private_chat_screen.dart';
import '../posts/public_image_posts_list.dart';
import 'public_things_questions_list.dart';
import 'widgets/bio_widget.dart';
import 'widgets/poll_images_stack.dart';
import 'widgets/profile_stats_tiles.dart';

// Follow Status Enum - Updated to match API response
enum FollowStatus { none, rechase, chase, both, pending }

// ignore: must_be_immutable
class PublicProfile extends StatefulWidget {
  int userId;
  PublicProfile({super.key, required this.userId});

  @override
  State<PublicProfile> createState() => _PublicProfileState();
}

class _PublicProfileState extends State<PublicProfile>
    with WidgetsBindingObserver, TickerProviderStateMixin, UtilityMixin {
  final ScrollController _scrollController = ScrollController();

  final _dio = Dio();

  // Animation controller and variables for scroll functionality
  late AnimationController _animationController;
  late Animation<double> _slideAnimationChaseRechase;
  late Animation<double> _slideAnimationPollsThings;
  bool _isVisible = true;
  double _lastScrollOffset = 0;
  final double _scrollThreshold = 10.0;
  bool isExpanded = false;
  bool isLoading = true;
  bool autoRefreshEnabled = true;

  final bool _isChaseRequestSent = false;
  final bool _isLoadingChaseStatus = true;

  // Silent data loading futures
  Future<List<PublicPost>>? _pollsFuture;
  late PublicPoll publicPollsQuestion;

  List<PublicPost> cachedPollPosts = [];
  List<PublicPost> cachedThingsPosts = [];

  final ApiService apiService = ApiService();

  // Friend status management
  FollowStatus? _localFollowStatus;
  bool _isProcessingRequest = false;

  // Image caching - Store image URLs for network loading
  String? _cachedProfilePictureUrl;
  String? _cachedCoverPictureUrl;
  Uint8List? _cachedProfileImageBytes;
  Uint8List? _cachedCoverImageBytes;

  bool _imagesInitialized = false;

  @override
  void initState() {
    super.initState();
    debugPrint('PublicProfile userId: ${widget.userId}');
    autoRefreshEnabled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PublicProfileProvider>().fetchPublicUserProfile(
        widget.userId,
      );

      // Initialize with empty data to show "No posts" initially

      _pollsFuture = Future.value(<PublicPost>[]);

      // Load fresh data silently in background
      _loadFreshPostsData();
      _loadFreshPollsData();
    });

    // Initialize animation controller
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimationChaseRechase = Tween<double>(begin: 0.0, end: -1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _slideAnimationPollsThings = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _scrollController.addListener(_scrollListener);
  }

  // Initialize images once and cache URLs
  void _initializeImages(profile) {
    if (!_imagesInitialized && profile != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_imagesInitialized) {
          String? profileUrl;
          String? coverUrl;

          // Use thumbnail URLs if available, otherwise use full URLs
          if (profile.profileThumbnailUrl != null &&
              profile.profileThumbnailUrl.isNotEmpty) {
            profileUrl = profile.profileThumbnailUrl;
          } else if (profile.profilePictureUrl != null &&
              profile.profilePictureUrl.isNotEmpty) {
            profileUrl = profile.profilePictureUrl;
          }

          if (profile.coverThumbnailUrl != null &&
              profile.coverThumbnailUrl.isNotEmpty) {
            coverUrl = profile.coverThumbnailUrl;
          }

          if (mounted) {
            setState(() {
              _cachedProfilePictureUrl = profileUrl;
              _cachedCoverPictureUrl = coverUrl;
              _imagesInitialized = true;
            });
          }
        }
      });
    }
  }

  // Reset cache when user changes
  @override
  void didUpdateWidget(covariant PublicProfile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) {
      setState(() {
        _imagesInitialized = false;
        _cachedProfilePictureUrl = null;
        _cachedCoverPictureUrl = null;
      });
    }
  }

  // Helper method to determine if posts should be visible
  bool _canViewPosts(bool isFriend, bool isPrivate) {
    // Logic breakdown:
    // is_private = false → always show posts (return true)
    // is_private = true AND is_friend = true → show posts (return true)
    // is_private = true AND is_friend = false → don't show posts (return false)

    if (!isPrivate) {
      return true; // Account is public, always show posts
    }
    return isFriend; // Account is private, show only if they're friends
  }

  // Helper method to determine effective friend status
  FollowStatus _getEffectiveFollowStatus(String? profileFollowStatus) {
    // If we have a local status change, use that
    if (_localFollowStatus != null) {
      return _localFollowStatus!;
    }

    // Otherwise, parse the profile data
    return _parseFollowStatus(profileFollowStatus);
  }

  FollowStatus _parseFollowStatus(String? status) {
    if (status == null || status.isEmpty) return FollowStatus.none;

    switch (status.toLowerCase()) {
      case 'following':
        return FollowStatus.rechase;
      case 'followers':
        return FollowStatus.chase;
      case 'both':
        return FollowStatus.both;
      case 'pending':
        return FollowStatus.pending;
      default:
        return FollowStatus.none;
    }
  }

  // Helper method to get button state
  Map<String, dynamic> _getButtonState(FollowStatus status) {
    switch (status) {
      case FollowStatus.none:
        return {
          'icon': FeatherIcons.userPlus,
          'text': 'Chase',
          'canTap': !_isProcessingRequest,
          'isFollowing': false,
        };
      case FollowStatus.chase:
        return {
          'icon': Icons.sync,
          'text': 'Chase Back',
          'canTap': !_isProcessingRequest,
          'isFollowing': false,
        };
      case FollowStatus.rechase:
      case FollowStatus.both:
        return {
          'icon': Icons.verified,
          'text': 'Chased',
          'canTap': !_isProcessingRequest,
          'isFollowing': true,
        };
      case FollowStatus.pending:
        return {
          'icon': Icons.schedule,
          'text': 'Chasing',
          'canTap': false,
          'isFollowing': false,
        };
    }
  }

  // Method to handle friend/unfriend actions
  // Method to handle follow/unfollow actions
  Future<void> _handleFollowAction(
    String username,
    bool isFollowing,
    bool isPrivate,
  ) async {
    if (_isProcessingRequest) return;

    setState(() {
      _isProcessingRequest = true;
    });

    try {
      Map<String, dynamic> response;

      if (isFollowing) {
        // Unfollow action - Update UI immediately
        setState(() {
          _localFollowStatus = FollowStatus.none;
          _isProcessingRequest = false;
        });

        // Make API call in background
        response = await apiService.unfriend(widget.userId);

        if (response['status'] == 'success') {
          // if (mounted) {
          //   ScaffoldMessenger.of(context).showSnackBar(
          //     const SnackBar(
          //       content: Text('Unfollowed successfully!'),
          //       backgroundColor: Colors.orange,
          //       duration: Duration(seconds: 2),
          //     ),
          //   );
          // }
          // No screen reload - just silent background update if needed
        } else {
          // Revert if failed
          setState(() {
            _localFollowStatus = FollowStatus.rechase;
          });

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
      } else {
        // Send follow/friend request
        // If profile is public, immediately show "Chased" (Following)
        // If profile is private, show "Chasing" (Pending)
        setState(() {
          _localFollowStatus = isPrivate
              ? FollowStatus.pending
              : FollowStatus.rechase;
          _isProcessingRequest = false;
        });

        // Make API call in background
        final bool requestResult = await apiService.sendFriendRequest(username);

        if (requestResult) {
          //
        } else {
          // Revert if failed
          setState(() {
            _localFollowStatus = null;
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Failed to send follow request. Please try again.',
                ),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 2),
              ),
            );
          }
        }
      }
    } catch (e) {
      // Revert on error
      setState(() {
        _localFollowStatus = null;
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

  void _loadFreshPostsData() {
    apiService
        .fetchPostsWithImages(widget.userId)
        .then((freshPosts) {
          if (mounted) {
            setState(() {});
          }
        })
        .catchError((error) {
          //  debugPrint("Error loading fresh posts: $error");
        });
  }

  void _loadFreshPollsData() {
    apiService
        .fetchPublicPostsPolls(widget.userId)
        .then((freshPolls) {
          if (mounted) {
            // Cache image posts
            final imagePosts = freshPolls.where((post) {
              if (post.polls.isEmpty) return false;
              return post.polls.any(
                (poll) => poll.options.any((option) => option.image != null),
              );
            }).toList();

            // Cache text posts
            final textPosts = freshPolls.where((post) {
              if (post.polls.isEmpty) return false;
              return post.polls.any(
                (poll) => poll.options.any((option) => option.text != null),
              );
            }).toList();

            setState(() {
              _pollsFuture = Future.value(freshPolls);
              cachedPollPosts = imagePosts;
              cachedThingsPosts = textPosts;
            });
          }
        })
        .catchError((error) {});
  }

  void _refreshPostsData() {
    _loadFreshPostsData();
  }

  void _refreshPollsData() {
    _loadFreshPollsData();
  }

  void _refreshAllData() {
    _refreshPostsData();
    _refreshPollsData();
  }

  void _scrollListener() {
    final currentScrollOffset = _scrollController.offset;
    final scrollDelta = currentScrollOffset - _lastScrollOffset;

    if (scrollDelta.abs() > _scrollThreshold) {
      if (scrollDelta > 0 && _isVisible) {
        _hideLeftShowRight();
      } else if (scrollDelta < 0 && !_isVisible) {
        _showLeftHideRight();
      }
      _lastScrollOffset = currentScrollOffset;
    }
  }

  void _hideLeftShowRight() {
    if (_isVisible) {
      _isVisible = false;
      _animationController.forward();
      setState(() {});
    }
  }

  void _showLeftHideRight() {
    if (!_isVisible) {
      _isVisible = true;
      _animationController.reverse();
      setState(() {});
    }
  }

  // Helper method to build network image URL
  String _getFullImageUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    // If URL already starts with http/https, return as is
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url;
    }
    // Otherwise, prepend base URL
    return '${ApiConfig.baseUrlImage}$url';
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    _animationController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      body: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Consumer<PublicProfileProvider>(
              builder: (context, publicProfileProvider, child) {
                if (publicProfileProvider.isLoading) {
                  return const PublicProfileSimmer();
                }
                // ERROR STATE
                if (publicProfileProvider.error != null) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 80,
                            color: Colors.red[300],
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Oops! Something went wrong',
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            publicProfileProvider.error!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: () {
                              debugPrint(
                                '🔄 Retry button pressed for: ${widget.userId}',
                              );
                              publicProfileProvider.fetchPublicUserProfile(
                                widget.userId,
                              );
                            },
                            icon: const Icon(Icons.refresh),
                            label: const Text('Try Again'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final profile = publicProfileProvider.userProfile;
                if (profile == null) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(height: 250.h),
                        Icon(
                          Icons.person_off,
                          size: 80,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No profile data available',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'The user profile could not be loaded',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  );
                }

                // Initialize images ONCE
                _initializeImages(profile);

                // Get effective friend status from profile data
                final effectiveStatus = _getEffectiveFollowStatus(
                  profile.followStatus,
                );
                // Get button state based on effective status
                final buttonState = _getButtonState(effectiveStatus);

                // Determine if user is friend (for posts visibility)
                final isFriend =
                    effectiveStatus == FollowStatus.rechase ||
                    effectiveStatus == FollowStatus.both;

                // Determine if posts can be viewed based on privacy settings
                final canViewPosts = _canViewPosts(isFriend, profile.isPrivate);

                return Column(
                  children: [
                    RepaintBoundary(
                      child: Container(
                        height: 180.h,
                        width: double.infinity,
                        padding: EdgeInsets.all(8.w),
                        decoration: BoxDecoration(
                          image: _cachedCoverPictureUrl != null
                              ? DecorationImage(
                                  image: MemoryImage(
                                    getConvertImage(profile.coverThumbnailUrl)!,
                                  ),
                                  fit: BoxFit.fill,
                                )
                              : const DecorationImage(
                                  image: AssetImage(
                                    Assets.assetsImagesDefaultCover,
                                  ),
                                  fit: BoxFit.fill,
                                ),
                        ),
                        child: Stack(
                          children: [
                            Align(
                              alignment: Alignment.bottomCenter,
                              child:
                                  Container(
                                    width: double.infinity,
                                    padding: EdgeInsets.all(8.w),
                                    child: Row(
                                      children: [
                                        // Profile Picture
                                        Container(
                                          height: 50.h,
                                          width: 50.h,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: Colors.white,
                                              width: 1.5.w,
                                            ),
                                            image:
                                                _cachedProfilePictureUrl != null
                                                ? DecorationImage(
                                                    image: MemoryImage(
                                                      getConvertImage(
                                                        profile
                                                            .profilePictureUrl,
                                                      )!,
                                                    ),
                                                    fit: BoxFit.cover,
                                                  )
                                                : const DecorationImage(
                                                    image: AssetImage(
                                                      Assets.assetsImagesIcUser,
                                                    ),
                                                    fit: BoxFit.fill,
                                                  ),
                                          ),
                                        ),
                                        SizedBox(width: 10.w),
                                        Expanded(
                                          child: LayoutBuilder(
                                            builder: (context, constraints) {
                                              return Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  // Username
                                                  Flexible(
                                                    child: Text(
                                                      profile.username,
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 13.5.sp,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  SizedBox(height: 2.h),

                                                  // Bio with advanced text handling
                                                  BioWidget(
                                                    maxWidth:
                                                        constraints.maxWidth,
                                                    userBio: profile.bio ?? '',
                                                    isExpanded: isExpanded,
                                                    onToggleExpand: () {
                                                      setState(() {
                                                        isExpanded =
                                                            !isExpanded;
                                                      });
                                                    },
                                                  ),
                                                  Row(
                                                    children: [
                                                      // Chase/Chased Button
                                                      GestureDetector(
                                                        onTap:
                                                            buttonState['canTap']
                                                            ? () {
                                                                _handleFollowAction(
                                                                  profile
                                                                      .username,
                                                                  buttonState['isFollowing'],
                                                                  profile
                                                                      .isPrivate,
                                                                );
                                                              }
                                                            : null,
                                                        child: Container(
                                                          height: 25.h,
                                                          width: 100
                                                              .w, // Changed from 100.w
                                                          margin:
                                                              EdgeInsets.only(
                                                                top: 4.h,
                                                              ),
                                                          decoration: BoxDecoration(
                                                            color: AppColors
                                                                .primaryColor
                                                                .withOpacity(
                                                                  buttonState['canTap']
                                                                      ? 0.8
                                                                      : 0.5,
                                                                ),
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  8.r,
                                                                ),
                                                          ),
                                                          child: Row(
                                                            mainAxisAlignment:
                                                                MainAxisAlignment
                                                                    .center,
                                                            children: [
                                                              Icon(
                                                                buttonState['icon'],
                                                                size: 14
                                                                    .sp, // Changed from 15.sp
                                                                color: Colors
                                                                    .white,
                                                              ),
                                                              SizedBox(
                                                                width: 3.w,
                                                              ), // Changed from 4.w
                                                              Flexible(
                                                                // Added Flexible wrapper
                                                                child: Text(
                                                                  buttonState['text'],
                                                                  style: TextStyle(
                                                                    color: Colors
                                                                        .white,
                                                                    fontSize:
                                                                        10.8.sp,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w500,
                                                                  ),
                                                                  overflow:
                                                                      TextOverflow
                                                                          .ellipsis, // Added overflow handling
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                      GestureDetector(
                                                        onTap: () {
                                                          final currentUsername =
                                                              Provider.of<
                                                                    UserProvider
                                                                  >(
                                                                    context,
                                                                    listen:
                                                                        false,
                                                                  )
                                                                  .username;

                                                          Navigator.push(
                                                            context,
                                                            MaterialPageRoute(
                                                              builder: (_) => ChangeNotifierProvider(
                                                                create: (_) => PrivateChatProvider()
                                                                  ..init(
                                                                    memberName:
                                                                        profile
                                                                            .username,
                                                                    profileUrl:
                                                                        profile
                                                                            .profilePictureUrl,
                                                                    chatId: profile
                                                                        .chatId,
                                                                    currentUsername:
                                                                        currentUsername,
                                                                  ),
                                                                child: PrivateChatScreen(
                                                                  userId:
                                                                      profile
                                                                          .id,
                                                                  memberName:
                                                                      profile
                                                                          .username,
                                                                  profileUrl:
                                                                      profile
                                                                          .profilePictureUrl,
                                                                  chatId: profile
                                                                      .chatId,
                                                                ),
                                                              ),
                                                            ),
                                                          );
                                                        },
                                                        child: Container(
                                                          height: 25.h,
                                                          width: 100.w,
                                                          margin:
                                                              EdgeInsets.only(
                                                                left: 8.w,
                                                                top: 4.h,
                                                              ),
                                                          decoration: BoxDecoration(
                                                            color: AppColors
                                                                .whiteColor
                                                                .withOpacity(
                                                                  0.3,
                                                                ),
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  8.r,
                                                                ),
                                                          ),
                                                          child: Icon(
                                                            FeatherIcons
                                                                .messageSquare,
                                                            size: 17.sp,
                                                            color: Colors.white,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              );
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ).asGlass(
                                    tintColor: Colors.black,
                                    clipBorderRadius: BorderRadius.circular(
                                      12.r,
                                    ),
                                  ),
                            ),
                            Positioned(
                              top: 16.h,
                              child: GestureDetector(
                                onTap: () {
                                  Navigator.pop(context);
                                },
                                child: Container(
                                  padding: EdgeInsets.all(8.w),
                                  child: Icon(
                                    Icons.arrow_back_ios,
                                    size: 21.spMax,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Main Content Area with Stats and Chase/Re-chase
                    // Only show if can view posts
                    !canViewPosts
                        ? const SizedBox.shrink()
                        : Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Stats Column - Animated (slides left to hide)
                              SizedBox(
                                width: 100, // Fixed width when visible
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 80.w,
                                      height: 80.h,
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).primaryColor,
                                        borderRadius: BorderRadius.circular(
                                          20.r,
                                        ),
                                      ),
                                      padding: EdgeInsets.symmetric(
                                        vertical: 8.h,
                                      ),
                                      margin: EdgeInsets.fromLTRB(
                                        10.w,
                                        10.h,
                                        10.w,
                                        0,
                                      ),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceAround,
                                        children: [
                                          statTile(
                                            FeatherIcons.arrowUp,
                                            profile.followersCount.toString(),
                                            () {
                                              navigationPush(
                                                context,
                                                PublicChaseList(
                                                  userId: profile.id,
                                                  username: profile.username,
                                                  initialIndex: 0,
                                                  chaseList: profile.chaseList,
                                                  rechaseList: profile.rechaseList,
                                                ),
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      width: 80.w,
                                      height: 80.h,
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).primaryColor,
                                        borderRadius: BorderRadius.circular(
                                          20.r,
                                        ),
                                      ),
                                      padding: EdgeInsets.symmetric(
                                        vertical: 7.h,
                                      ),
                                      margin: EdgeInsets.fromLTRB(
                                        10.w,
                                        5.h,
                                        10.w,
                                        0,
                                      ),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceAround,
                                        children: [
                                          statTile(
                                            FeatherIcons.arrowDown,
                                            profile.followingCount.toString(),
                                            () {
                                              navigationPush(
                                                context,
                                                PublicChaseList(
                                                  userId: profile.id,
                                                  username: profile.username,
                                                  initialIndex: 1,
                                                  chaseList: profile.chaseList,
                                                  rechaseList: profile.rechaseList,
                                                ),
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Chase / Re-chase Section
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(height: 10.h),
                                    // Revibe (Rechase) Section
                                    Row(
                                      children: [
                                        Text(
                                          AppLocalizations.of(context)!.vibe,
                                          style: TextStyle(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onBackground,
                                            fontSize: 11.sp,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const Spacer(),
                                        GestureDetector(
                                          onTap: () {
                                            navigationPush(
                                              context,
                                              PublicChaseList(
                                                userId: profile.id,
                                                username: profile.username,
                                                initialIndex: 0,
                                                chaseList: profile.chaseList,
                                                  rechaseList: profile.rechaseList,
                                              ),
                                            );
                                          },
                                          child: Padding(
                                            padding: EdgeInsets.only(
                                              right: 10.w,
                                            ),
                                            child: Row(
                                              children: [
                                                if (profile
                                                    .chaseList!
                                                    .isNotEmpty)
                                                  Text(
                                                    '${AppLocalizations.of(context)!.seeall} >',
                                                    style: TextStyle(
                                                      color: Theme.of(
                                                        context,
                                                      ).colorScheme.primary,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      fontSize: 10.5.sp,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 5.h),
                                    SizedBox(
                                      height: 55.h,
                                      child:
                                          (profile.chaseList?.isEmpty ?? true)
                                          ? Center(
                                              child: Text(
                                                'No chase users',
                                                style: TextStyle(
                                                  color: Colors.grey,
                                                  fontSize: 10.4.sp,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            )
                                          : ListView.builder(
                                              scrollDirection: Axis.horizontal,
                                              shrinkWrap: true,
                                              itemCount:
                                                  (profile.chaseList!.length >
                                                      4)
                                                  ? 4
                                                  : profile.chaseList!.length,
                                              itemBuilder: (context, index) {
                                                final chaseUser =
                                                    profile.chaseList![index];
                                                return GestureDetector(
                                                  onTap: () {
                                                    navigationPush(
                                                      context,
                                                      PublicProfile(
                                                        userId:
                                                            chaseUser.userId,
                                                      ),
                                                    );
                                                  },
                                                  child: Container(
                                                    height: 55.h,
                                                    width: 55.w,
                                                    margin: EdgeInsets.only(
                                                      right: 8.w,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      shape: BoxShape.circle,
                                                      border: Border.all(
                                                        width: 1.w,
                                                        color: const Color(
                                                          0xFFD1D1D1,
                                                        ).withOpacity(0.7),
                                                      ),
                                                      color: Theme.of(context)
                                                          .primaryColor
                                                          .withOpacity(0.08),
                                                      image:
                                                          chaseUser.avatarUrl !=
                                                                  null &&
                                                              chaseUser
                                                                  .avatarUrl!
                                                                  .isNotEmpty
                                                          ? DecorationImage(
                                                              image: MemoryImage(
                                                                getConvertImage(
                                                                  chaseUser
                                                                      .avatarUrl,
                                                                )!,
                                                              ),
                                                              fit: BoxFit.cover,
                                                            )
                                                          : null,
                                                    ),
                                                    child:
                                                        chaseUser.avatarUrl ==
                                                                null ||
                                                            chaseUser
                                                                .avatarUrl!
                                                                .isEmpty
                                                        ? Center(
                                                            child: Text(
                                                              chaseUser
                                                                      .username
                                                                      .isNotEmpty
                                                                  ? chaseUser
                                                                        .username[0]
                                                                        .toUpperCase()
                                                                  : '?',
                                                              style: TextStyle(
                                                                color: Theme.of(
                                                                  context,
                                                                ).primaryColor,
                                                                fontSize: 20.sp,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                              ),
                                                            ),
                                                          )
                                                        : null,
                                                  ),
                                                );
                                              },
                                            ),
                                    ),

                                    SizedBox(height: 10.h),
                                    // Vibe (Chase) Section
                                    Row(
                                      children: [
                                        Text(
                                          AppLocalizations.of(context)!.revibe,
                                          style: TextStyle(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onBackground,
                                            fontSize: 11.sp,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const Spacer(),
                                        GestureDetector(
                                          onTap: () {
                                            navigationPush(
                                              context,
                                              PublicChaseList(
                                                userId: profile.id,
                                                username: profile.username,
                                                initialIndex: 1,
                                                chaseList: profile.chaseList,
                                                  rechaseList: profile.rechaseList,
                                              ),
                                            );
                                          },
                                          child: Padding(
                                            padding: EdgeInsets.only(
                                              right: 10.w,
                                            ),
                                            child: Row(
                                              children: [
                                                if (profile
                                                    .rechaseList!
                                                    .isNotEmpty)
                                                  Text(
                                                    '${AppLocalizations.of(context)!.seeall} >',
                                                    style: TextStyle(
                                                      color: Theme.of(
                                                        context,
                                                      ).colorScheme.primary,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      fontSize: 10.5.sp,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 5.h),
                                    SizedBox(
                                      height: 55.h,
                                      child:
                                          (profile.rechaseList?.isEmpty ?? true)
                                          ? Center(
                                              child: Text(
                                                'No rechase users',
                                                style: TextStyle(
                                                  color: Colors.grey,
                                                  fontSize: 10.4.sp,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            )
                                          : ListView.builder(
                                              scrollDirection: Axis.horizontal,
                                              shrinkWrap: true,
                                              itemCount:
                                                  (profile.rechaseList!.length >
                                                      4)
                                                  ? 4
                                                  : profile.rechaseList!.length,
                                              itemBuilder: (context, index) {
                                                final rechaseUser =
                                                    profile.rechaseList![index];
                                                return GestureDetector(
                                                  onTap: () {
                                                    navigationPush(
                                                      context,
                                                      PublicProfile(
                                                        userId:
                                                            rechaseUser.userId,
                                                      ),
                                                    );
                                                  },
                                                  child: Container(
                                                    height: 55.h,
                                                    width: 55.w,
                                                    margin: EdgeInsets.only(
                                                      right: 8.w,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      shape: BoxShape.circle,
                                                      border: Border.all(
                                                        color: const Color(
                                                          0xFFD1D1D1,
                                                        ).withOpacity(0.7),
                                                      ),
                                                      color: Theme.of(context)
                                                          .primaryColor
                                                          .withOpacity(0.08),
                                                      image:
                                                          rechaseUser.avatarUrl !=
                                                                  null &&
                                                              rechaseUser
                                                                  .avatarUrl!
                                                                  .isNotEmpty
                                                          ? DecorationImage(
                                                              image: MemoryImage(
                                                                getProfileImage(
                                                                  rechaseUser
                                                                      .avatarUrl,
                                                                )!,
                                                              ),
                                                              fit: BoxFit.cover,
                                                            )
                                                          : null,
                                                    ),
                                                    child:
                                                        rechaseUser.avatarUrl ==
                                                                null ||
                                                            rechaseUser
                                                                .avatarUrl!
                                                                .isEmpty
                                                        ? Center(
                                                            child: Text(
                                                              rechaseUser
                                                                      .username
                                                                      .isNotEmpty
                                                                  ? rechaseUser
                                                                        .username[0]
                                                                        .toUpperCase()
                                                                  : '?',
                                                              style: TextStyle(
                                                                color: Theme.of(
                                                                  context,
                                                                ).primaryColor,
                                                                fontSize: 20.sp,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                              ),
                                                            ),
                                                          )
                                                        : null,
                                                  ),
                                                );
                                              },
                                            ),
                                    ),
                                    SizedBox(height: 12.h),
                                  ],
                                ),
                              ),
                            ],
                          ),

                    // Show privacy message if posts cannot be viewed
                    canViewPosts
                        ? const SizedBox.shrink()
                        : Column(
                            children: [
                              Container(
                                width: double.infinity,
                                height: 46.h,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF9A2C3E),
                                  borderRadius: BorderRadius.circular(10.r),
                                ),
                                padding: EdgeInsets.symmetric(vertical: 5.h),
                                margin: EdgeInsets.only(
                                  left: 10.w,
                                  right: 10.w,
                                  top: 10.h,
                                  bottom: 70.h,
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: [
                                    SizedBox(
                                      width: 55.w,
                                      child: Column(
                                        children: [
                                          Row(
                                            children: [
                                              Image.asset(
                                                Assets.assetsImagesCurrentUser,
                                                height: 16.h,
                                                width: 16.w,
                                              ),
                                              SizedBox(width: 2.h),
                                              Icon(
                                                FeatherIcons.arrowLeft,
                                                size: 17.spMax,
                                                color: Colors.white.withOpacity(
                                                  0.8,
                                                ),
                                              ),
                                              SizedBox(width: 2.h),
                                              Image.asset(
                                                Assets.assetsImagesAddUsers,
                                                height: 16.h,
                                                width: 16.w,
                                              ),
                                            ],
                                          ),
                                          SizedBox(height: 2.h),
                                          Text(
                                            profile.followersCount.toString(),
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 12.5.sp,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    SizedBox(
                                      height: 30.h,
                                      child: const VerticalDivider(
                                        color: Color(0xA7FFFFFF),
                                        thickness: 0.63,
                                        width: 1,
                                      ),
                                    ),
                                    SizedBox(
                                      width: 55.w,
                                      child: Column(
                                        children: [
                                          Row(
                                            children: [
                                              Image.asset(
                                                Assets.assetsImagesCurrentUser,
                                                height: 16.h,
                                                width: 16.w,
                                              ),
                                              SizedBox(width: 2.h),
                                              Icon(
                                                FeatherIcons.arrowRight,
                                                size: 17.spMax,
                                                color: Colors.white.withOpacity(
                                                  0.8,
                                                ),
                                              ),
                                              SizedBox(width: 2.h),
                                              Image.asset(
                                                Assets.assetsImagesAddUsers,
                                                height: 16.h,
                                                width: 16.w,
                                              ),
                                            ],
                                          ),
                                          SizedBox(height: 2.h),
                                          Text(
                                            profile.followingCount.toString(),
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 12.5.sp,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    SizedBox(
                                      height: 30.h,
                                      child: const VerticalDivider(
                                        color: Color(0xA7FFFFFF),
                                        thickness: 0.63,
                                        width: 1,
                                      ),
                                    ),
                                    pollThingsTile(
                                      Assets.assetsImagesPoll,
                                      (profile.imagePostCount).toString(),
                                      () {},
                                    ),
                                    SizedBox(
                                      height: 30.h,
                                      child: const VerticalDivider(
                                        color: Color(0xA7FFFFFF),
                                        thickness: 0.63,
                                        width: 1,
                                      ),
                                    ),
                                    pollThingsTile(
                                      Assets.assetsImagesThings,
                                      (profile.textPostCount).toString(),
                                      () {},
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                FeatherIcons.lock,
                                color: Theme.of(context).colorScheme.primary,
                                size: 40.spMax,
                              ),
                              SizedBox(height: 5.h),
                              Text(
                                '${profile.username}\'s posts are private',
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onBackground,
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 8.h),
                              Text(
                                'Start chasing to see their photos and updates.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onBackground.withOpacity(0.4),
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              GestureDetector(
                                onTap: isFriend || _isProcessingRequest
                                    ? null
                                    : () {
                                        _handleFollowAction(
                                          profile.username,
                                          false,
                                          profile.isPrivate,
                                        );
                                      },
                                child: Container(
                                  height: 30.h,
                                  width: 120.w,
                                  margin: EdgeInsets.only(top: 12.h),
                                  decoration: BoxDecoration(
                                    color: _isProcessingRequest
                                        ? AppColors.primaryColor.withOpacity(
                                            0.5,
                                          )
                                        : AppColors.primaryColor,
                                    borderRadius: BorderRadius.circular(8.r),
                                  ),
                                  child: Center(
                                    child: _isProcessingRequest
                                        ? SizedBox(
                                            width: 20.sp,
                                            height: 20.sp,
                                            child:
                                                const CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  valueColor:
                                                      AlwaysStoppedAnimation<
                                                        Color
                                                      >(Colors.white),
                                                ),
                                          )
                                        : Text(
                                            'Start Chasing',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 11.5.sp,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                  ),
                                ),
                              ),
                            ],
                          ),

                    // Posts count section - Show if can view posts
                    !canViewPosts
                        ? const SizedBox.shrink()
                        : Container(
                            width: double.infinity,
                            height: 38.h,
                            decoration: BoxDecoration(
                              color: Theme.of(context).primaryColor,
                              borderRadius: BorderRadius.circular(10.r),
                            ),
                            margin: EdgeInsets.only(
                              left: 10.w,
                              right: 10.w,
                              top: 10.h,
                              bottom: 10.h,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                GestureDetector(
                                  onTap: () {},
                                  child: Container(
                                    color: Colors.transparent,
                                    width: 55.w,
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          (profile.imagePostCount).toString(),
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 13.sp,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        SizedBox(width: 5.w),
                                        Image.asset(
                                          Assets.assetsImagesPoll,
                                          height: 18.h,
                                          width: 18.w,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  height: 30.h,
                                  child: const VerticalDivider(
                                    color: Color(0xA7FFFFFF),
                                    thickness: 0.63,
                                    width: 1,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () {},
                                  child: Container(
                                    color: Colors.transparent,
                                    width: 55.w,
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          (profile.textPostCount).toString(),
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 13.sp,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        SizedBox(width: 5.w),
                                        Image.asset(
                                          Assets.assetsImagesThings,
                                          height: 18.h,
                                          width: 18.w,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                    // Poll section header
                    !canViewPosts
                        ? const SizedBox.shrink()
                        : Padding(
                            padding: EdgeInsets.fromLTRB(10.w, 0, 10.w, 0.h),
                            child: Row(
                              children: [
                                Text(
                                  AppLocalizations.of(context)!.poll,
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onBackground,
                                    fontSize: 11.sp,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const Spacer(),
                                if (cachedPollPosts.isNotEmpty)
                                  GestureDetector(
                                    onTap: () {
                                      navigationPush(
                                        context,
                                        PublicImagePostsList(
                                          userId: profile.id,
                                          username: profile.username,
                                          profileImage:
                                              profile.profilePictureUrl,
                                        ),
                                      );
                                    },
                                    child: Row(
                                      children: [
                                        Text(
                                          '${AppLocalizations.of(context)!.seeall} >',
                                          style: TextStyle(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 10.5.sp,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),

                    // Posts grid
                    !canViewPosts
                        ? const SizedBox.shrink()
                        : Padding(
                            padding: EdgeInsets.symmetric(horizontal: 10.w),
                            child: FutureBuilder<List<PublicPost>>(
                              key: ValueKey(_pollsFuture.hashCode),
                              future: _pollsFuture,
                              builder: (context, snapshot) {
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return Shimmer.fromColors(
                                    baseColor: Colors.grey[300]!,
                                    highlightColor: Colors.grey[100]!,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        SizedBox(height: 10.h),
                                        Container(
                                          height: 120.h,
                                          width: double.infinity,
                                          margin: EdgeInsets.only(bottom: 5.h),
                                          decoration: BoxDecoration(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.secondaryContainer,
                                            borderRadius: BorderRadius.circular(
                                              10.r,
                                            ),
                                          ),
                                        ),
                                        Container(
                                          height: 120.h,
                                          width: double.infinity,
                                          margin: EdgeInsets.only(bottom: 5.h),
                                          decoration: BoxDecoration(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.secondaryContainer,
                                            borderRadius: BorderRadius.circular(
                                              10.r,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }

                                if (snapshot.hasError) {
                                  return Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.error_outline,
                                          color: Colors.grey[600],
                                          size: 50,
                                        ),
                                        SizedBox(height: 10.h),
                                        Text(
                                          'Error loading posts',
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 12.sp,
                                          ),
                                        ),
                                        SizedBox(height: 10.h),
                                        ElevatedButton(
                                          onPressed: _refreshPostsData,
                                          child: const Text('Retry'),
                                        ),
                                      ],
                                    ),
                                  );
                                }

                                final allPosts = snapshot.data ?? [];

                                // Filter posts that have polls with image options
                                final postsWithPollImages = allPosts.where((
                                  post,
                                ) {
                                  // Check if post has polls
                                  if (post.polls.isEmpty) return false;

                                  // Check if any poll has options with images
                                  return post.polls.any((poll) {
                                    return poll.options.any(
                                      (option) => option.image != null,
                                    );
                                  });
                                }).toList();

                                if (postsWithPollImages.isEmpty) {
                                  return Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        SizedBox(height: 30.h),
                                        Icon(
                                          Icons.photo_library_outlined,
                                          size: 32.spMax,
                                          color: Colors.grey.withOpacity(0.5),
                                        ),
                                        SizedBox(height: 10.h),
                                        Text(
                                          AppLocalizations.of(
                                            context,
                                          )!.nopostwithimage,
                                          style: TextStyle(
                                            color: Colors.grey,
                                            fontSize: 10.4.sp,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        SizedBox(height: 10.h),
                                      ],
                                    ),
                                  );
                                }

                                return GridView.builder(
                                  padding: EdgeInsets.only(top: 10.h),
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 2,
                                        crossAxisSpacing: 8,
                                        mainAxisSpacing: 8,
                                        childAspectRatio: 1.3,
                                      ),
                                  itemCount: postsWithPollImages.length > 4
                                      ? 4
                                      : postsWithPollImages.length,
                                  itemBuilder: (context, index) {
                                    final post = postsWithPollImages[index];
                                    // Extract images from poll options
                                    final pollImages = post.polls
                                        .expand((poll) => poll.options)
                                        .where((option) => option.image != null)
                                        .map((option) => option.image!)
                                        .toList();

                                    return GestureDetector(
                                      onTap: () {
                                        navigationPush(
                                          context,
                                          PublicImagePostsList(
                                            userId: profile.id,
                                            username: profile.username,
                                            profileImage:
                                                profile.profilePictureUrl,
                                          ),
                                        );
                                      },
                                      child: PollImagesStack(pollImages),
                                    );
                                  },
                                );
                              },
                            ),
                          ),

                    // Things section header
                    !canViewPosts
                        ? const SizedBox.shrink()
                        : Padding(
                            padding: EdgeInsets.fromLTRB(10.w, 10.h, 10.w, 0.h),
                            child: Row(
                              children: [
                                Text(
                                  AppLocalizations.of(context)!.things,
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onBackground,
                                    fontSize: 11.sp,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const Spacer(),
                                if (cachedThingsPosts.isNotEmpty)
                                  GestureDetector(
                                    onTap: () {
                                      navigationPush(
                                        context,
                                        PublicThingsQuestionsList(
                                          username: profile.username,
                                          profileImage:
                                              profile.profilePictureUrl,
                                          userId: profile.id,
                                        ),
                                      );
                                    },
                                    child: Row(
                                      children: [
                                        Text(
                                          '${AppLocalizations.of(context)!.seeall} >',
                                          style: TextStyle(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 10.5.sp,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),

                    // Things/Polls list
                    !canViewPosts
                        ? const SizedBox.shrink()
                        : FutureBuilder<List<PublicPost>>(
                            key: ValueKey(_pollsFuture.hashCode),
                            future: _pollsFuture,
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return Shimmer.fromColors(
                                  baseColor: Colors.grey[300]!,
                                  highlightColor: Colors.grey[100]!,
                                  child: Column(
                                    children: [
                                      Container(
                                        height: 100.h,
                                        width: double.infinity,
                                        margin: EdgeInsets.all(12.w),
                                        decoration: BoxDecoration(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.secondaryContainer,
                                          borderRadius: BorderRadius.circular(
                                            10.r,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }
                              if (snapshot.hasError) {
                                return Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.error_outline,
                                        color: Colors.grey[600],
                                        size: 50,
                                      ),
                                      SizedBox(height: 10.h),
                                      Text(
                                        'Error loading polls',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 12.sp,
                                        ),
                                      ),
                                      SizedBox(height: 10.h),
                                      ElevatedButton(
                                        onPressed: _refreshPollsData,
                                        child: const Text('Retry'),
                                      ),
                                    ],
                                  ),
                                );
                              }

                              final allPosts = snapshot.data ?? <PublicPost>[];

                              // FILTERING LOGIC:
                              // 1. Get posts that have polls
                              // 2. Filter polls where ALL options have text != null (ignore image-based options)
                              // 3. Take only first 3 posts
                              final filteredPosts = allPosts
                                  .where((post) {
                                    // Check if post has polls
                                    if (post.polls.isEmpty) return false;

                                    // Check if any poll has at least one option with text != null
                                    return post.polls.any((poll) {
                                      return poll.options.any(
                                        (option) => option.text != null,
                                      );
                                    });
                                  })
                                  .take(3)
                                  .toList(); // Take only first 3

                              if (filteredPosts.isEmpty) {
                                return Center(
                                  child: Column(
                                    children: [
                                      SizedBox(height: 30.h),
                                      Text(
                                        AppLocalizations.of(
                                          context,
                                        )!.nopostswiththings,
                                        style: TextStyle(
                                          color: Colors.grey,
                                          fontSize: 10.4.sp,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }

                              return ListView.builder(
                                padding: const EdgeInsets.all(12),
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: filteredPosts.length,
                                itemBuilder: (context, index) {
                                  const List<List<Color>> gradientOptions = [
                                    [Color(0xFFFC3E7E), Color(0xFFEEA0F0)],
                                    [Color(0xFF4FC3F7), Color(0xFFB6E2F8)],
                                    [Colors.red, Color(0xFFEFB0C3)],
                                  ];

                                  return PublicPollTextCard(
                                    publicPost: filteredPosts[index],
                                    gradientColors:
                                        gradientOptions[index %
                                            gradientOptions.length],
                                  );
                                },
                              );
                            },
                          ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

Widget pollThingsTile(String icon, String value, VoidCallback onTap) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      color: Colors.transparent,
      width: 55.w,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(icon, height: 16.h, width: 16.w),
          SizedBox(height: 2.h),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: 12.5.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    ),
  );
}
