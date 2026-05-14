import re

file_path = "lib/screens/home/profile/public/new_public_profile_screen.dart"

with open(file_path, "r") as f:
    content = f.read()

# 1. Update build method
build_start = """  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    final publicProfileProvider = Provider.of<PublicProfileProvider>(context);"""

build_new = """  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    final publicProfileProvider = Provider.of<PublicProfileProvider>(context);

    final profile = publicProfileProvider.userProfile;
    final effectiveStatus = _getEffectiveFollowStatus(profile?.followStatus);
    final isFriend = effectiveStatus == FollowStatus.rechase || effectiveStatus == FollowStatus.both;
    final canViewPosts = profile != null ? (!profile.isPrivate || isFriend) : true;"""

content = content.replace(build_start, build_new)

# 2. Hide SliverPersistentHeader
header_old = """            SliverPersistentHeader(
              pinned: true,
              delegate: _SliverAppBarDelegate(
                TabBar("""

header_new = """            if (canViewPosts)
              SliverPersistentHeader(
                pinned: true,
                delegate: _SliverAppBarDelegate(
                  TabBar("""

content = content.replace(header_old, header_new)

# 3. Replace body content
body_old = """        body: TabBarView(
          controller: _tabController,
          children: [
            isLoadingPosts
                ? Center(
                    child: Loader(color: Theme.of(context).colorScheme.primary),
                  )
                : cachedThingsPosts.isEmpty
                ? const Center(child: Text('No things'))
                : ListView.builder(
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
                    child: Loader(color: Theme.of(context).colorScheme.primary),
                  )
                : cachedImagesPosts.isEmpty
                ? const Center(child: Text('No images'))
                : ListView.builder(
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
        ),"""

body_new = """        body: canViewPosts
            ? TabBarView(
                controller: _tabController,
                children: [
                  isLoadingPosts
                      ? Center(
                          child: Loader(color: Theme.of(context).colorScheme.primary),
                        )
                      : cachedThingsPosts.isEmpty
                      ? const Center(child: Text('No things'))
                      : ListView.builder(
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
                          child: Loader(color: Theme.of(context).colorScheme.primary),
                        )
                      : cachedImagesPosts.isEmpty
                      ? const Center(child: Text('No images'))
                      : ListView.builder(
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
                    Icon(
                      FeatherIcons.lock,
                      size: 40.sp,
                      color: Theme.of(context).colorScheme.onBackground.withOpacity(0.5),
                    ),
                    SizedBox(height: 10.h),
                    Text(
                      'This account is private',
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onBackground.withOpacity(0.7),
                      ),
                    ),
                    SizedBox(height: 5.h),
                    Text(
                      'Chase this account to see their posts.',
                      style: AppTextStyles.subText.copyWith(
                        fontSize: 14.sp,
                        color: Theme.of(context).colorScheme.onBackground.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ),"""

content = content.replace(body_old, body_new)

with open(file_path, "w") as f:
    f.write(content)

