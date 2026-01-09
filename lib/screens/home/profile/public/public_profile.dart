// ignore_for_file: deprecated_member_use, unused_local_variable, unused_field, unused_element

import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:feather_icons/feather_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:glass/glass.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../api/api_config.dart';
import '../../../../api/services/api_service.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_images.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../mixin/utility_mixins.dart';
import '../../../../models/public/images/public_user_posts.dart';
import '../../../../models/public/things/public_post_things_model.dart';
import '../../../../models/public/things/public_things_card.dart';
import '../../../../models/public/things/things_question.dart';
import '../../../../provider/public_profile_provider.dart';
import '../../../../widgets/base64/image_convert.dart';
import '../../../../widgets/simmer/public_profile_simmer.dart';
import '../posts/public_posts_list.dart';
import 'public_things_questions_list.dart';

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

  bool _isChaseRequestSent = false;
  bool _isLoadingChaseStatus = true;

  // Silent data loading futures
  Future<List<PublicPost>>? _postsFuture;
  Future<List<PublicPostPolls>>? _pollsFuture;

  late PublicPollsQuestion publicPollsQuestion;

  final ApiService apiService = ApiService();

  @override
  void initState() {
    super.initState();
    autoRefreshEnabled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PublicProfileProvider>().fetchPublicUserProfile(
        widget.userId,
      );

      // Initialize with empty data to show "No posts" initially
      _postsFuture = Future.value(<PublicPost>[]);
      _pollsFuture = Future.value(<PublicPostPolls>[]);

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

  void _loadFreshPostsData() {
    apiService
        .fetchPostsWithImages(widget.userId)
        .then((freshPosts) {
          if (mounted) {
            _postsFuture = Future.value(freshPosts);
            setState(() {});
          }
        })
        .catchError((error) {
          debugPrint("Error loading fresh posts: $error");
        });
  }

  void _loadFreshPollsData() {
    apiService
        .fetchPublicPostsPolls(widget.userId)
        .then((freshPolls) {
          if (mounted) {
            _pollsFuture = Future.value(freshPolls);
            setState(() {});
          }
        })
        .catchError((error) {
          debugPrint("Error loading fresh polls: $error");
        });
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

  Uint8List? getProfileImage(profile_picture) {
    if (profile_picture == null || profile_picture.isEmpty) return null;
    try {
      String base64Data = profile_picture.replaceFirst(
        RegExp(r'data:image/[^;]+;base64,'),
        '',
      );
      return base64Decode(base64Data);
    } catch (e) {
      return null;
    }
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
      body: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Consumer<PublicProfileProvider>(
              builder: (context, publicProfileProvider, child) {
                if (publicProfileProvider.isLoading) {
                  return PublicProfileSimmer();
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
                              print(
                                '🔄 Retry button pressed for: ${widget.userId}',
                              );
                              publicProfileProvider.fetchPublicUserProfile(
                                widget.userId,
                              );
                            },
                            icon: Icon(Icons.refresh),
                            label: Text('Try Again'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(
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

                return Column(
                  children: [
                    Container(
                      height: 180.h,
                      width: double.infinity,
                      padding: EdgeInsets.all(8.w),
                      decoration: BoxDecoration(
                        image: (profile.coverPictureUrl.isEmpty)
                            ? DecorationImage(
                                image: AssetImage(
                                  Assets.assetsImagesDefaultCover,
                                ),
                                fit: BoxFit.fill,
                              )
                            : DecorationImage(
                                image: MemoryImage(
                                  getConvertImage(profile.coverPictureUrl)!,
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
                                              (profile
                                                  .profilePictureUrl
                                                  .isEmpty)
                                              ? DecorationImage(
                                                  image: AssetImage(
                                                    Assets.assetsImagesIcUser,
                                                  ),
                                                  fit: BoxFit.fill,
                                                )
                                              : DecorationImage(
                                                  image: MemoryImage(
                                                    getConvertImage(
                                                      profile.profilePictureUrl,
                                                    )!,
                                                  ),
                                                  fit: BoxFit.cover,
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

                                                // Name
                                                Text(
                                                  '${profile.firstName} ${profile.lastName}',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 12.5.sp,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                                SizedBox(height: 3.h),

                                                // Bio with advanced text handling
                                                _buildBioWidget(
                                                  constraints.maxWidth,
                                                  profile.bio,
                                                ),
                                                Row(
                                                  children: [
                                                    Container(
                                                      height: 25.h,
                                                      width: 90.w,
                                                      margin: EdgeInsets.only(
                                                        top: 4.h,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color: AppColors
                                                            .primaryColor
                                                            .withOpacity(0.8),
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
                                                          profile.isFriend
                                                              ? Icon(
                                                                  Icons
                                                                      .verified,
                                                                  size: 15.sp,
                                                                  color: Colors
                                                                      .white,
                                                                )
                                                              : Icon(
                                                                  FeatherIcons
                                                                      .userPlus,
                                                                  size: 15.sp,
                                                                  color: Colors
                                                                      .white,
                                                                ),
                                                          SizedBox(width: 4.w),
                                                          profile.isFriend
                                                              ? Text(
                                                                  'Chased',
                                                                  style: TextStyle(
                                                                    color: Colors
                                                                        .white,
                                                                    fontSize:
                                                                        11.3.sp,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w500,
                                                                  ),
                                                                )
                                                              : Text(
                                                                  'Chase',
                                                                  style: TextStyle(
                                                                    color: Colors
                                                                        .white,
                                                                    fontSize:
                                                                        11.3.sp,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w500,
                                                                  ),
                                                                ),
                                                        ],
                                                      ),
                                                    ),
                                                    Container(
                                                      height: 25.h,
                                                      width: 50.w,
                                                      margin: EdgeInsets.only(
                                                        left: 10.w,
                                                        top: 4.h,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color: AppColors
                                                            .whiteColor
                                                            .withOpacity(0.3),
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
                                  clipBorderRadius: BorderRadius.circular(12.r),
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

                    // Main Content Area with Stats and Chase/Re-chase
                    (profile.isFriend == false)
                        ? SizedBox.shrink()
                        : Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Stats Column - Animated (slides left to hide)
                              // Use flex: 0 when hidden, flex: 1 when visible for proper space allocation
                              SizedBox(
                                width: 100, // Fixed width when visible
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 80.w,
                                      height: 80.h,
                                      decoration: BoxDecoration(
                                        color: Color(0xFF9A2C3E),
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
                                            () {},
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      width: 80.w,
                                      height: 80.h,
                                      decoration: BoxDecoration(
                                        color: Color(0xFF9A2C3E),
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
                                            () {},
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Chase/Re-chase Section - Now properly expands to fill remaining width
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(height: 10.h),
                                  Row(
                                    children: [
                                      Text(
                                        AppLocalizations.of(context)!.revibe,
                                        style: TextStyle(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onBackground,
                                          fontSize: 11.5.sp,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 5.h),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    children: [
                                      Container(
                                        height: 55.h,
                                        width: 55.w,
                                        margin: EdgeInsets.only(right: 8.w),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          image: DecorationImage(
                                            image: AssetImage(
                                              Assets.assetsImagesIcUser,
                                            ),
                                          ),
                                        ),
                                      ),
                                      Container(
                                        height: 55.h,
                                        width: 55.w,
                                        margin: EdgeInsets.only(right: 8.w),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          image: DecorationImage(
                                            image: AssetImage(
                                              Assets.assetsImagesIcUser,
                                            ),
                                          ),
                                        ),
                                      ),
                                      Container(
                                        height: 55.h,
                                        width: 55.w,
                                        margin: EdgeInsets.only(right: 8.w),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          image: DecorationImage(
                                            image: AssetImage(
                                              Assets.assetsImagesIcUser,
                                            ),
                                          ),
                                        ),
                                      ),
                                      Container(
                                        height: 55.h,
                                        width: 55.w,
                                        margin: EdgeInsets.only(right: 8.w),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          image: DecorationImage(
                                            image: AssetImage(
                                              Assets.assetsImagesIcUser,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 8.h),
                                  Row(
                                    children: [
                                      Text(
                                        AppLocalizations.of(context)!.vibe,
                                        style: TextStyle(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onBackground,
                                          fontSize: 11.5.sp,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 5.h),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    children: [
                                      Container(
                                        height: 55.h,
                                        width: 55.w,
                                        margin: EdgeInsets.only(right: 8.w),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          image: DecorationImage(
                                            image: AssetImage(
                                              Assets.assetsImagesIcUser,
                                            ),
                                          ),
                                        ),
                                      ),
                                      Container(
                                        height: 55.h,
                                        width: 55.w,
                                        margin: EdgeInsets.only(right: 8.w),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          image: DecorationImage(
                                            image: AssetImage(
                                              Assets.assetsImagesIcUser,
                                            ),
                                          ),
                                        ),
                                      ),
                                      Container(
                                        height: 55.h,
                                        width: 55.w,
                                        margin: EdgeInsets.only(right: 8.w),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          image: DecorationImage(
                                            image: AssetImage(
                                              Assets.assetsImagesIcUser,
                                            ),
                                          ),
                                        ),
                                      ),
                                      Container(
                                        height: 55.h,
                                        width: 55.w,
                                        margin: EdgeInsets.only(right: 8.w),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          image: DecorationImage(
                                            image: AssetImage(
                                              Assets.assetsImagesIcUser,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 5.h),
                                ],
                              ),
                            ],
                          ),
                    (profile.isFriend == false)
                        ? Column(
                            children: [
                              Container(
                                width: double.infinity, // Full device width
                                height: 46.h,
                                decoration: BoxDecoration(
                                  color: Color(0xFF9A2C3E),
                                  borderRadius: BorderRadius.circular(10.r),
                                ),
                                padding: EdgeInsets.symmetric(vertical: 5.h),
                                margin: EdgeInsets.only(
                                  left: 10.w,
                                  right: 10.w,
                                  top: 10.h,
                                  bottom: 70.h,
                                ), // Remove horizontal margins for full width
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
                                    Container(
                                      height: 30.h,
                                      child: VerticalDivider(
                                        color: const Color(0xA7FFFFFF),
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
                                    Container(
                                      height: 30.h,
                                      child: VerticalDivider(
                                        color: const Color(0xA7FFFFFF),
                                        thickness: 0.63,
                                        width: 1,
                                      ),
                                    ),
                                    pollThingsTile(
                                      Assets.assetsImagesPoll,
                                      (profile.imagePostCount).toString(),
                                      () {},
                                    ),
                                    Container(
                                      height: 30.h,
                                      child: VerticalDivider(
                                        color: const Color(0xA7FFFFFF),
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
                                onTap: () {
                                  publicProfileProvider.sendFriendRequest(
                                    profile.username,
                                  );
                                },
                                child: Container(
                                  height: 30.h,
                                  width: 120.w,
                                  margin: EdgeInsets.only(top: 12.h),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryColor,
                                    borderRadius: BorderRadius.circular(8.r),
                                  ),
                                  child: Center(
                                    child: Text(
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
                          )
                        : Container(
                            width: double.infinity, // Full device width
                            height: 38.h,
                            decoration: BoxDecoration(
                              color: Color(0xFF9A2C3E),
                              borderRadius: BorderRadius.circular(10.r),
                            ),
                            // padding: EdgeInsets.symmetric(vertical: 5.h),
                            margin: EdgeInsets.only(
                              left: 10.w,
                              right: 10.w,
                              top: 10.h,
                              bottom: 10.h.h,
                            ), // Remove horizontal margins for full width
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
                                          '${(profile.imagePostCount).toString()}',
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

                                Container(
                                  height: 30.h,
                                  child: VerticalDivider(
                                    color: const Color(0xA7FFFFFF),
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
                                          '${(profile.textPostCount).toString()}',
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
                    (profile.isFriend == false)
                        ? SizedBox.shrink()
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
                                    fontSize: 11.5.sp,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Spacer(),
                                GestureDetector(
                                  onTap: () {
                                    navigationPush(
                                      context,
                                      PublicPostsList(userId: profile.id),
                                    );
                                  },
                                  child: Row(
                                    children: [
                                      Text(
                                        AppLocalizations.of(context)!.seeall,
                                        style: TextStyle(
                                          fontSize: 11.2.sp,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.primaryColor
                                              .withOpacity(0.8),
                                        ),
                                      ),
                                      Icon(
                                        Icons.arrow_forward_ios,
                                        size: 15.5.spMax,
                                        color: AppColors.primaryColor
                                            .withOpacity(0.8),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                    (profile.isFriend == false)
                        ? SizedBox.shrink()
                        : Padding(
                            padding: EdgeInsets.symmetric(horizontal: 10.w),
                            child: FutureBuilder<List<PublicPost>>(
                              key: ValueKey(_postsFuture.hashCode),
                              future: _postsFuture,
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
                                          child: Text('Retry'),
                                        ),
                                      ],
                                    ),
                                  );
                                }

                                final postsWithImages = snapshot.data ?? [];
                                if (postsWithImages.isEmpty) {
                                  return Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        SizedBox(height: 10.h),
                                        Icon(
                                          Icons.photo_library_outlined,
                                          size: 45.spMax,
                                          color: Colors.grey.withOpacity(0.5),
                                        ),
                                        SizedBox(height: 10.h),
                                        Text(
                                          'No posts with image',
                                          style: TextStyle(
                                            fontSize: 11.5.sp,
                                            color: Colors.grey,
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
                                  itemCount: postsWithImages.length > 4
                                      ? 4
                                      : postsWithImages.length,
                                  itemBuilder: (context, index) {
                                    final posts = postsWithImages[index];
                                    return _buildImagesStack(posts.images);
                                  },
                                );
                              },
                            ),
                          ),
                    (profile.isFriend == false)
                        ? SizedBox.shrink()
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
                                    fontSize: 11.5.sp,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Spacer(),
                                GestureDetector(
                                  onTap: () {
                                    navigationPush(
                                      context,
                                      PublicThingsQuestionsList(
                                        userId: profile.id,
                                      ),
                                    );
                                  },
                                  child: Row(
                                    children: [
                                      Text(
                                        AppLocalizations.of(context)!.seeall,
                                        style: TextStyle(
                                          fontSize: 11.2.sp,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.primaryColor
                                              .withOpacity(0.8),
                                        ),
                                      ),
                                      Icon(
                                        Icons.arrow_forward_ios,
                                        size: 15.5.spMax,
                                        color: AppColors.primaryColor
                                            .withOpacity(0.8),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                    (profile.isFriend == false)
                        ? SizedBox.shrink()
                        : FutureBuilder<List<PublicPostPolls>>(
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
                                        child: Text('Retry'),
                                      ),
                                    ],
                                  ),
                                );
                              }

                              final postsPolls =
                                  snapshot.data ?? const <PublicPostPolls>[];
                              if (postsPolls.isEmpty) {
                                return Center(
                                  child: Column(
                                    children: [
                                      SizedBox(height: 20.h),
                                      Text(
                                        'No posts with things',
                                        style: TextStyle(
                                          fontSize: 11.5.sp,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }
                              final postsWithPolls = postsPolls
                                  .where(
                                    (post) =>
                                        post.publicPollQuestion.isNotEmpty,
                                  )
                                  .toList();

                              if (postsWithPolls.isEmpty) {
                                return const Center(
                                  child: Text('No active polls found'),
                                );
                              }

                              return ListView.builder(
                                padding: const EdgeInsets.all(12),
                                shrinkWrap: true,
                                physics: NeverScrollableScrollPhysics(),
                                itemCount: postsWithPolls.length > 3
                                    ? 3
                                    : postsWithPolls.length,
                                itemBuilder: (context, index) {
                                  const List<List<Color>> gradientOptions = [
                                    [Color(0xFFFC3E7E), Color(0xFFEEA0F0)],
                                    [Color(0xFF4FC3F7), Color(0xFFB6E2F8)],
                                    [Colors.red, const Color(0xFFEFB0C3)],
                                  ];
                                  return PublicThingsCard(
                                    publicPosts: postsWithPolls[index],
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

  Widget _buildBioWidget(double maxWidth, String userbio) {
    final bio = userbio;
    if (bio.isEmpty) return SizedBox.shrink();

    final textStyle = TextStyle(color: Colors.white, fontSize: 11.3.sp);

    final textSpan = TextSpan(text: bio, style: textStyle);
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
      maxLines: 2,
    );

    textPainter.layout(maxWidth: maxWidth);

    final isTextOverflowing = textPainter.didExceedMaxLines;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedContainer(
          duration: Duration(milliseconds: 300),
          child: Text(
            bio,
            style: textStyle,
            maxLines: isExpanded ? null : 2,
            overflow: isExpanded ? null : TextOverflow.ellipsis,
          ),
        ),
        if (isTextOverflowing) ...[
          SizedBox(height: 3.h),
          GestureDetector(
            onTap: () {
              setState(() {
                isExpanded = !isExpanded;
              });
            },
            child: Text(
              isExpanded ? 'Read Less' : 'Read More',
              style: TextStyle(
                color: Colors.blue.shade300,
                fontSize: 11.sp,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

Widget statTile(IconData icon, String value, VoidCallback onTap) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      color: Colors.transparent,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Image.asset(
                Assets.assetsImagesCurrentUser,
                height: 18.5.h,
                width: 18.5.w,
              ),
              SizedBox(height: 2.h),
              Icon(icon, size: 20.spMax, color: Colors.white.withOpacity(0.8)),
              SizedBox(height: 2.h),
              Image.asset(
                Assets.assetsImagesAddUsers,
                height: 18.5.h,
                width: 18.5.w,
              ),
            ],
          ),
          SizedBox(width: 5.h),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: 14.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    ),
  );
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

Widget _buildImagesStack(List images) {
  List<Alignment> getAlignments(int totalImages) {
    switch (totalImages) {
      case 1:
        return [Alignment.center];
      case 2:
        return [Alignment.centerLeft, Alignment.centerRight];
      case 3:
        return [Alignment.centerLeft, Alignment.center, Alignment.centerRight];
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

  List<Alignment> alignments = getAlignments(images.length);

  return LayoutBuilder(
    builder: (context, constraints) {
      double availableWidth = constraints.maxWidth;
      double availableHeight = constraints.maxHeight;
      double imageHeight = 120.h;

      return SizedBox(
        height: availableHeight,
        width: availableWidth,
        child: Stack(
          children: images
              .asMap()
              .entries
              .map<Widget>((entry) {
                int index = entry.key;
                dynamic imageData = entry.value;
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
                        border: Border.all(color: Colors.white, width: 1),
                        borderRadius: BorderRadius.circular(20.r),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(19.r),
                        child: Image.network(
                          '${ApiConfig.baseUrlImage}${imageData.url}',
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                              child: Icon(
                                Icons.image_not_supported,
                                color: Colors.grey[600],
                                size: 30,
                              ),
                            );
                          },
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20.r),
                              ),
                              child: Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  value:
                                      loadingProgress.expectedTotalBytes != null
                                      ? loadingProgress.cumulativeBytesLoaded /
                                            loadingProgress.expectedTotalBytes!
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
      );
    },
  );
}
