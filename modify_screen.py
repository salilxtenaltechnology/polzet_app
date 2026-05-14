import re

file_path = "lib/screens/home/profile/public/new_public_profile_screen.dart"

with open(file_path, "r") as f:
    content = f.read()

# Add imports
imports_to_add = """
import '../../../../api/services/api_service.dart';
import '../../../../models/public/public_profile_model.dart';
import '../../../../core/constants/app_icons.dart';
import '../../../../api/api_config.dart';
"""
if "import '../../../../api/services/api_service.dart';" not in content:
    content = content.replace("import 'chase/public_chase_list.dart';", "import 'chase/public_chase_list.dart';\n" + imports_to_add)

# Add state variables
state_vars = """
  final ApiService apiService = ApiService();
  bool isLoadingPosts = true;
  List<PublicPost> cachedThingsPosts = [];
  List<PublicPost> cachedImagesPosts = [];

  Map<int, bool> postLikeStates = {};
  Map<int, int> postLikeCounts = {};
"""
content = re.sub(r'class _NewPublicProfileScreenState extends State<NewPublicProfileScreen>\s+with SingleTickerProviderStateMixin,\s*UtilityMixin\s*{',
                 r'class _NewPublicProfileScreenState extends State<NewPublicProfileScreen>\n    with SingleTickerProviderStateMixin, UtilityMixin {\n' + state_vars,
                 content)

# Add _loadData in initState
init_state_replacement = """  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PublicProfileProvider>().fetchPublicUserProfile(
        widget.userId,
      );
      _loadData();
    });
  }"""
content = re.sub(r'  @override\n  void initState\(\) \{.*?\n  \}', init_state_replacement, content, flags=re.DOTALL)

# Add _loadData function and other helpers
helpers = """
  void _loadData() {
    setState(() {
      isLoadingPosts = true;
    });

    Future.wait([
      apiService.fetchPostsWithImages(widget.userId).then((posts) {
        if (mounted) {
          setState(() {
            cachedImagesPosts = posts;
          });
        }
      }).catchError((_) {}),
      apiService.fetchPublicPostsPolls(widget.userId).then((posts) {
        if (mounted) {
          setState(() {
            cachedThingsPosts = posts.where((post) {
              if (post.polls.isEmpty) return false;
              return post.polls.any(
                (poll) => poll.options.any((option) => option.text != null),
              );
            }).toList();
          });
        }
      }).catchError((_) {}),
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
    if (post.polls.isEmpty) return const SizedBox.shrink();
    final poll = post.polls.first;

    final isLiked = postLikeStates[post.id] ?? post.isLiked;
    final likesCount = postLikeCounts[post.id] ?? post.likesCount;
    final commentsCount = post.comments.length;
    final profile = userProvider.userProfile;

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
                  children: [
                    Text(
                      userProvider.isLoading || profile == null
                          ? '-'
                          : (profile.firstName.isNotEmpty
                              ? '${profile.firstName} ${profile.lastName}'.trim()
                              : profile.username),
                      style: AppTextStyles.sectionHeading.copyWith(
                        color: const Color(0XFF2C2C2C),
                        fontSize: 14,
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          userProvider.isLoading || profile == null
                              ? '-'
                              : '@${profile.username}',
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
                const Icon(
                  FeatherIcons.moreVertical,
                  size: 22,
                  color: Color(0xFF727272),
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
                  _buildTextOptions(poll, () {}),
                SizedBox(height: 16.h),
                Row(
                  children: [
                    GestureDetector(
                      onTap: () {},
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
                    Text('$likesCount'),
                    SizedBox(width: 16.w),
                    AppIcons.commnetBox(
                      color: Theme.of(
                        context,
                      ).colorScheme.onBackground.withOpacity(0.6),
                    ),
                    SizedBox(width: 4.w),
                    Text('$commentsCount'),
                    SizedBox(width: 16.w),
                    AppIcons.sharePost(
                      color: Theme.of(
                        context,
                      ).colorScheme.onBackground.withOpacity(0.7),
                    ),
                    const Spacer(),
                    Icon(
                      FeatherIcons.bookmark,
                      size: 20.sp,
                      color: Colors.black54,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextOptions(PublicPoll poll, VoidCallback onTap) {
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
                                  color: Theme.of(context).colorScheme.onBackground,
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
          onTap: () {},
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
                            ),
                          ),
                        ),
                      ),
                    );
                  })
                  .toList(),
            ),
          ),
        );
      },
    );
  }
"""

content = content.replace("  Widget _buildHeader", helpers + "\n  Widget _buildHeader")

# Replace TabBarView
tab_bar_view_replacement = """        body: TabBarView(
          controller: _tabController,
          children: [
            isLoadingPosts
                ? const Center(child: CircularProgressIndicator())
                : cachedThingsPosts.isEmpty
                    ? const Center(child: Text('No things'))
                    : ListView.builder(
                        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
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
                ? const Center(child: CircularProgressIndicator())
                : cachedImagesPosts.isEmpty
                    ? const Center(child: Text('No images'))
                    : ListView.builder(
                        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
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
        ),"""
content = re.sub(r'        body: TabBarView\(\n.*?controller: _tabController,\n.*?children: const \[\n.*?Center\(child: Text\(\'No things\'\)\),\n.*?Center\(child: Text\(\'No images\'\)\),\n.*?\],\n.*?\),', tab_bar_view_replacement, content, flags=re.DOTALL)

with open(file_path, "w") as f:
    f.write(content)
