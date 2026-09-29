// ignore_for_file: deprecated_member_use

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../api/api_service.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_radius.dart';
import '../../../core/themes/app_text_styles.dart';
import '../../../gen/assets.gen.dart';
import '../../../languages/l10n/generated/app_localizations.dart';
import '../../../mixin/utility_mixins.dart';
import '../../../models/user/suggestionsb users/suggestions_users_model.dart';
import '../../../widgets/appbar/common_appbar.dart';
import '../../../widgets/error/api_error_widget.dart';
import '../../../widgets/loader.dart';
import '../profile/public/public_profile_screen.dart';

class SuggestedUsersList extends StatefulWidget {
  const SuggestedUsersList({super.key});

  @override
  State<SuggestedUsersList> createState() => _SuggestedUsersListState();
}

class _SuggestedUsersListState extends State<SuggestedUsersList>
    with UtilityMixin {
  final ApiService apiService = ApiService();
  final Set<dynamic> _chasedUserIds = {};
  final Set<dynamic> _processingUserIds = {};

  final List<SuggestedUser> _users = [];
  final PageController _pageController = PageController();

  int _currentPageIndex = 0;
  int _apiCurrentPage = 1;
  bool _hasMore = true;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _isError = false;

  @override
  void initState() {
    super.initState();
    _fetchPage(1, isRefresh: true);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _fetchPage(int page, {bool isRefresh = false}) async {
    if (_isLoading || _isLoadingMore) return;

    setState(() {
      if (isRefresh) {
        _isLoading = true;
        _isError = false;
      } else {
        _isLoadingMore = true;
      }
    });

    try {
      final result = await apiService.fetchUserSuggestions(page: page);
      if (!mounted) return;

      setState(() {
        if (isRefresh) {
          _users.clear();
          _currentPageIndex = 0;
        }
        _users.addAll(result.data.peopleYouMayKnow);
        _apiCurrentPage = result.page;
        _hasMore = result.hasMore;
        _isLoading = false;
        _isLoadingMore = false;
        _isError = false;
      });
    } catch (e) {
      debugPrint('Error fetching suggested users page $page: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
        if (isRefresh && _users.isEmpty) {
          _isError = true;
        }
      });
    }
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentPageIndex = index;
    });

    final int totalPages = (_users.length / 4).ceil();
    if (index >= totalPages - 1 && _hasMore && !_isLoading && !_isLoadingMore) {
      _fetchPage(_apiCurrentPage + 1);
    }
  }

  Future<void> _handleChaseToggle(SuggestedUser user) async {
    if (_processingUserIds.contains(user.id)) return;

    final isChased = _chasedUserIds.contains(user.id);

    setState(() {
      _processingUserIds.add(user.id);
      if (isChased) {
        _chasedUserIds.remove(user.id);
      } else {
        _chasedUserIds.add(user.id);
      }
    });

    try {
      if (isChased) {
        // Unfriend / cancel
        final res = await apiService.unfriend(user.id);
        if (res['status'] != 'success') {
          // Attempt cancel request if unfriend failed
          await apiService.cancelFriendRequest(user.id);
        }
      } else {
        // Send friend request / Add
        final success = await apiService.sendFriendRequest(user.username);
        if (!success && mounted) {
          setState(() {
            _chasedUserIds.remove(user.id);
          });
        }
      }
    } catch (e) {
      debugPrint('Error toggling chase for ${user.username}: $e');
      if (mounted) {
        setState(() {
          if (isChased) {
            _chasedUserIds.add(user.id);
          } else {
            _chasedUserIds.remove(user.id);
          }
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _processingUserIds.remove(user.id);
        });
      }
    }
  }

  void _removeUser(dynamic userId) {
    setState(() {
      _users.removeWhere((u) => u.id == userId);
      final int newTotalPages = (_users.length / 4).ceil();
      if (_currentPageIndex >= newTotalPages && newTotalPages > 0) {
        _currentPageIndex = newTotalPages - 1;
        _pageController.jumpToPage(_currentPageIndex);
      }
    });

    if (_users.length < 4 && _hasMore && !_isLoading && !_isLoadingMore) {
      _fetchPage(_apiCurrentPage + 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    Widget bodyWidget;

    if (_isError && _users.isEmpty) {
      bodyWidget = ApiErrorWidget(
        onRetry: () => _fetchPage(1, isRefresh: true),
      );
    } else if (_isLoading && _users.isEmpty) {
      bodyWidget = Center(
        child: Loader(color: Theme.of(context).colorScheme.onPrimary),
      );
    } else if (_users.isEmpty) {
      bodyWidget = Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 64.sp,
              color: isDarkMode
                  ? Colors.white.withValues(alpha: 0.3)
                  : Colors.black.withValues(alpha: 0.3),
            ),
            SizedBox(height: 12.h),
            Text(
              'No suggestions available right now',
              style: AppTextStyles.bodyText.copyWith(
                fontSize: 14.sp,
                color: isDarkMode
                    ? Colors.white.withValues(alpha: 0.6)
                    : const Color(0xFF8E8E8E),
              ),
            ),
            SizedBox(height: 16.h),
            TextButton(
              onPressed: () => _fetchPage(1, isRefresh: true),
              child: Text(
                'Refresh',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      final int totalPages = (_users.length / 4).ceil();

      bodyWidget = LayoutBuilder(
        builder: (context, constraints) {
          final double availableWidth = constraints.maxWidth;

          // Responsive measurements for centered 2x2 layout
          final double horizontalPadding = 16.w;
          final double gridSpacing = 12.w;
          final double gridWidth = availableWidth - (horizontalPadding * 2);
          final double cardWidth = (gridWidth - gridSpacing) / 2;

          // Proportional card height matching target design
          final double cardHeight = 195.h;
          final double gridHeight = (cardHeight * 2) + gridSpacing;

          return RefreshIndicator(
            onRefresh: () => _fetchPage(1, isRefresh: true),
            color: Theme.of(context).colorScheme.primary,
            child: Column(
              children: [
                // ── Centered 2x2 Grid with Horizontal PageView ──
                Expanded(
                  child: Center(
                    child: SizedBox(
                      height: gridHeight,
                      child: PageView.builder(
                        controller: _pageController,
                        onPageChanged: _onPageChanged,
                        itemCount: totalPages,
                        physics: const BouncingScrollPhysics(),
                        itemBuilder: (context, pageIndex) {
                          final int startIndex = pageIndex * 4;
                          final int endIndex = math.min(
                            startIndex + 4,
                            _users.length,
                          );
                          final pageUsers = _users.sublist(
                            startIndex,
                            endIndex,
                          );

                          return Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: horizontalPadding,
                            ),
                            child: GridView.builder(
                              physics: const NeverScrollableScrollPhysics(),
                              padding: EdgeInsets.zero,
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    crossAxisSpacing: gridSpacing,
                                    mainAxisSpacing: gridSpacing,
                                    childAspectRatio: cardWidth / cardHeight,
                                  ),
                              itemCount: pageUsers.length,
                              itemBuilder: (context, index) {
                                final user = pageUsers[index];
                                return _buildUserCard(
                                  user: user,
                                  cardHeight: cardHeight,
                                  isDarkMode: isDarkMode,
                                );
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),

                // ── Horizontal Scroll Page Indicator ──
                if (totalPages > 1)
                  Padding(
                    padding: EdgeInsets.only(bottom: 24.h, top: 8.h),
                    child: _buildPageIndicator(
                      totalPages: totalPages,
                      currentPage: _currentPageIndex,
                      isDarkMode: isDarkMode,
                    ),
                  )
                else
                  SizedBox(height: 24.h),
              ],
            ),
          );
        },
      );
    }

    return Scaffold(
      backgroundColor: isDarkMode
          ? AppColors.darkBackgroundColor
          : Theme.of(context).colorScheme.background,
      appBar: CommonAppBar(
        title: AppLocalizations.of(context)!.discoverdusers,
        showBackButton: true,
      ),
      body: bodyWidget,
    );
  }

  // ── Single User Card ──
  Widget _buildUserCard({
    required SuggestedUser user,
    required double cardHeight,
    required bool isDarkMode,
  }) {
    final isChased = _chasedUserIds.contains(user.id);
    final isProcessing = _processingUserIds.contains(user.id);

    final double avatarRadius = 38.r;
    final double mutualAvatarRadius = 8.r;
    final double mutualOverlapShift = 10.w;
    final double mutualContainerHeight = 17.h;

    return Container(
      height: cardHeight,
      decoration: BoxDecoration(
        color: isDarkMode
            ? const Color(0xFF22232B)
            : Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDarkMode
              ? Colors.white.withValues(alpha: 0.09)
              : const Color(0xFFEFEFEF),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDarkMode ? 0.2 : 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          // ── Close / Remove Icon (Top-Right) ──
          Positioned(
            top: 6.h,
            right: 6.w,
            child: GestureDetector(
              onTap: () => _removeUser(user.id),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: EdgeInsets.all(4.w),
                child: Icon(
                  Icons.close_rounded,
                  size: 16.sp,
                  color: isDarkMode
                      ? Colors.white.withValues(alpha: 0.5)
                      : const Color(0XFF8E8E8E),
                ),
              ),
            ),
          ),

          // ── Main Card Contents ──
          Padding(
            padding: EdgeInsets.fromLTRB(10.w, 14.h, 10.w, 12.h),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // ── Top Section: Avatar + Name + Mutual ──
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── Avatar ──
                    GestureDetector(
                      onTap: () => navigationPush(
                        context,
                        PublicProfileScreen(
                          userId: user.id.toString(),
                          username: user.username,
                        ),
                      ),
                      child: (user.avatar.isNotEmpty &&
                              user.avatar != 'null' &&
                              user.avatar != Assets.images.icAvatar.path)
                          ? CircleAvatar(
                              radius: avatarRadius,
                              backgroundImage: user.avatarImageProvider,
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.onPrimary.withOpacity(0.08),
                            )
                          : CircleAvatar(
                              radius: avatarRadius,
                              backgroundImage: AssetImage(
                                Assets.images.icAvatar.path,
                              ),
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.onPrimary.withOpacity(0.1),
                            ),
                    ),

                    SizedBox(height: 6.h),

                    // ── Name ──
                    Text(
                      user.name.isNotEmpty ? user.name : user.username,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onBackground,
                      ),
                    ),

                    SizedBox(height: 3.h),

                    // ── Mutual Friends ──
                    SizedBox(
                      height: mutualContainerHeight,
                      child: user.mutualFriends > 0 &&
                              user.mutualFriendsAvatars.isNotEmpty
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  height: mutualContainerHeight,
                                  width:
                                      (user.mutualFriendsAvatars.take(3).length -
                                                  1) *
                                              mutualOverlapShift +
                                          mutualContainerHeight,
                                  child: Stack(
                                    children: List.generate(
                                      user.mutualFriendsAvatars.take(3).length,
                                      (imgIndex) {
                                        final img =
                                            user.mutualImageProviders[imgIndex];
                                        return Positioned(
                                          left: imgIndex * mutualOverlapShift,
                                          child: Container(
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: isDarkMode
                                                    ? const Color(0xFF22232B)
                                                    : Colors.white,
                                                width: 1,
                                              ),
                                            ),
                                            child: CircleAvatar(
                                              radius: mutualAvatarRadius,
                                              backgroundImage: img,
                                              backgroundColor: Theme.of(context)
                                                  .colorScheme
                                                  .onPrimary
                                                  .withOpacity(0.1),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                                SizedBox(width: 4.w),
                                Flexible(
                                  child: Text(
                                    '+${user.mutualFriends} mutual',
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                    style: AppTextStyles.subText.copyWith(
                                      fontSize: 10.sp,
                                      fontWeight: FontWeight.w400,
                                      color: isDarkMode
                                          ? Colors.white.withValues(alpha: 0.45)
                                          : const Color(0xFF8E8E8E),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : Text(
                              user.mutualFriends > 0
                                  ? '+${user.mutualFriends} Mutuals'
                                  : (user.role.isNotEmpty
                                      ? user.role
                                      : ''),
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: AppTextStyles.subText.copyWith(
                                fontSize: 10.5.sp,
                                fontWeight: FontWeight.w400,
                                color: isDarkMode
                                    ? Colors.white.withValues(alpha: 0.45)
                                    : const Color(0xFF8E8E8E),
                              ),
                            ),
                    ),
                  ],
                ),

                // ── Chase Action Button ──
                GestureDetector(
                  onTap: isProcessing ? null : () => _handleChaseToggle(user),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    height: 35,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: isChased
                          ? (isDarkMode
                                ? Colors.white.withValues(alpha: 0.05)
                                : const Color(0xFFF7F7F7))
                          : Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(AppRadius.button),
                      border: isChased
                          ? Border.all(
                              color: isDarkMode
                                  ? Colors.white.withValues(alpha: 0.25)
                                  : Theme.of(context).colorScheme.primary
                                        .withValues(alpha: 0.6),
                              width: 1.2,
                            )
                          : null,
                    ),
                    child: Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (!isChased) ...[
                            Icon(
                              Icons.add,
                              color: Colors.white,
                              size: 15.sp,
                            ),
                            SizedBox(width: 5.w),
                          ],
                          Text(
                            isChased ? 'Chasing' : 'Chase',
                            style: TextStyle(
                              color: isChased
                                  ? (isDarkMode
                                        ? Colors.white.withValues(
                                            alpha: 0.85,
                                          )
                                        : Theme.of(
                                            context,
                                          ).colorScheme.primary)
                                  : Colors.white,
                              fontSize: 11.5.sp,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
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

  // ── Bottom Page Indicator ──
  Widget _buildPageIndicator({
    required int totalPages,
    required int currentPage,
    required bool isDarkMode,
  }) {
    // Show maximum 5 indicator dots if totalPages is large
    final int displayCount = math.min(totalPages, 5);
    final int effectiveCurrent = currentPage.clamp(0, displayCount - 1);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(displayCount, (index) {
        final bool isSelected = index == effectiveCurrent;

        return GestureDetector(
          onTap: () {
            _pageController.animateToPage(
              index,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            margin: EdgeInsets.symmetric(horizontal: 3.5.w),
            height: 6.h,
            width: isSelected ? 16.w : 6.w,
            decoration: BoxDecoration(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : (isDarkMode
                        ? Colors.white.withValues(alpha: 0.22)
                        : const Color(0xFFDCDCDC)),
              borderRadius: BorderRadius.circular(4.r),
            ),
          ),
        );
      }),
    );
  }
}
