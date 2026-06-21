// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../api/services/validator/api_service.dart';
import '../../../core/constants/app_radius.dart';
import '../../../core/themes/app_text_styles.dart';
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

  final List<SuggestedUser> _users = [];
  int _currentPage = 1;
  bool _hasMore = true;
  bool _isLoading = false;
  bool _isError = false;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _fetchPage(1, isRefresh: true);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!mounted) return;
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent * 0.8 &&
        !_isLoading &&
        _hasMore) {
      _fetchPage(_currentPage + 1);
    }
  }

  Future<void> _fetchPage(int page, {bool isRefresh = false}) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      if (isRefresh) {
        _isError = false;
      }
    });

    try {
      final result = await apiService.fetchUserSuggestions(page: page);
      if (!mounted) return;

      setState(() {
        if (isRefresh) {
          _users.clear();
        }
        _users.addAll(result.data.peopleYouMayKnow);
        _currentPage = result.page;
        _hasMore = result.hasMore;
        _isLoading = false;
        _isError = false;
      });
    } catch (e) {
      debugPrint('Error fetching suggested users page $page: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isError = true;
      });
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
      bodyWidget = const SizedBox.shrink();
    } else {
      bodyWidget = LayoutBuilder(
        builder: (context, constraints) {
          final double totalWidth = constraints.maxWidth;
          final double totalHeight = constraints.maxHeight;

          final double horizontalPadding = 24.w;
          final double verticalPadding = 24.h;

          final double crossAxisSpacing = 12.w;
          final double mainAxisSpacing = 12.h;

          final double itemWidth =
              (totalWidth - horizontalPadding - crossAxisSpacing) / 2;
          final double itemHeight =
              (totalHeight - verticalPadding - (mainAxisSpacing * 3)) / 4;

          final double aspectRatio = itemWidth / itemHeight;

          return RefreshIndicator(
            onRefresh: () => _fetchPage(1, isRefresh: true),
            color: Theme.of(context).colorScheme.onPrimary,
            child: CustomScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 12.h,
                  ),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: crossAxisSpacing,
                      mainAxisSpacing: mainAxisSpacing,
                      childAspectRatio: aspectRatio,
                    ),
                    delegate: SliverChildBuilderDelegate((context, i) {
                      final user = _users[i];

                      return StatefulBuilder(
                        builder: (context, setLocalState) {
                          final isChased = _chasedUserIds.contains(user.id);

                          // Dynamically calculate padding, avatar radius, spacing and font sizes
                          // based on calculated itemHeight to perfectly fit 4 rows in mobile screen.
                          final double cardPadding = (itemHeight * 0.08).clamp(
                            8.0,
                            20.0,
                          );
                          final double avatarRadius = (itemHeight * 0.18).clamp(
                            24.0,
                            45.0,
                          );
                          final double nameFontSize = (itemHeight * 0.06).clamp(
                            11.0,
                            14.0,
                          );
                          final double mutualFontSize = (itemHeight * 0.05)
                              .clamp(10.0, 12.0);
                          final double buttonFontSize = (itemHeight * 0.048)
                              .clamp(9.0, 11.0);

                          final double spacing1 = (itemHeight * 0.035).clamp(
                            4.0,
                            8.0,
                          );
                          final double spacing2 = (itemHeight * 0.022).clamp(
                            2.0,
                            5.0,
                          );
                          final double buttonTopMargin = (itemHeight * 0.05)
                              .clamp(4.0, 12.0);
                          final double buttonHeight = (itemHeight * 0.14).clamp(
                            26.0,
                            32.0,
                          );

                          final double mutualAvatarRadius =
                              (avatarRadius * 0.20).clamp(8.0, 10.0);
                          final double mutualOverlapShift =
                              mutualAvatarRadius * 1.2;
                          final double mutualContainerHeight =
                              mutualAvatarRadius * 2 + 2.0;

                          return Container(
                            padding: EdgeInsets.symmetric(
                              vertical: cardPadding,
                              horizontal: 12,
                            ),
                            decoration: BoxDecoration(
                              color: isDarkMode
                                  ? const Color(0xFF2A2A2E)
                                  : Theme.of(
                                      context,
                                    ).colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(
                                AppRadius.card,
                              ),
                              border: Border.all(
                                color: isDarkMode
                                    ? Colors.white.withValues(alpha: 0.08)
                                    : const Color(0xFFEFEFEF),
                                width: 1,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x06000000),
                                  blurRadius: 2,
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // ── Avatar ──
                                GestureDetector(
                                  onTap: () => navigationPush(
                                    context,
                                    PublicProfileScreen(
                                      userId: user.id.toString(),
                                    ),
                                  ),
                                  child: user.avatar.isNotEmpty
                                      ? CircleAvatar(
                                          radius: avatarRadius,
                                          backgroundImage:
                                              user.avatarImageProvider,
                                          backgroundColor: Theme.of(context)
                                              .colorScheme
                                              .onPrimary
                                              .withOpacity(0.1),
                                        )
                                      : CircleAvatar(
                                          radius: avatarRadius,
                                          backgroundColor: Theme.of(context)
                                              .colorScheme
                                              .onPrimary
                                              .withOpacity(0.1),
                                          child: Text(
                                            user.username.isNotEmpty
                                                ? user.username[0].toUpperCase()
                                                : 'P',
                                            style: TextStyle(
                                              fontSize: (avatarRadius * 0.6).sp,
                                              fontWeight: FontWeight.w600,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onPrimary
                                                  .withValues(alpha: 0.8),
                                            ),
                                          ),
                                        ),
                                ),

                                SizedBox(height: spacing1),

                                // ── Name ──
                                Text(
                                  user.name,
                                  textAlign: TextAlign.center,
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                  style: AppTextStyles.bodyText.copyWith(
                                    fontSize: nameFontSize,
                                    fontWeight: FontWeight.w600,
                                    color: isDarkMode
                                        ? Colors.white
                                        : Theme.of(
                                            context,
                                          ).colorScheme.onBackground,
                                  ),
                                ),

                                SizedBox(height: spacing2),

                                // ── Mutuals ──
                                if (user.mutualFriends > 0)
                                  if (user.mutualFriendsAvatars.isNotEmpty)
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        SizedBox(
                                          height: mutualContainerHeight,
                                          width:
                                              (user.mutualFriendsAvatars
                                                          .take(3)
                                                          .length -
                                                      1) *
                                                  mutualOverlapShift +
                                              mutualContainerHeight,
                                          child: Stack(
                                            children: List.generate(
                                              user.mutualFriendsAvatars
                                                  .take(3)
                                                  .length,
                                              (index) {
                                                final img = user
                                                    .mutualImageProviders[index];
                                                return Positioned(
                                                  left:
                                                      index *
                                                      mutualOverlapShift,
                                                  child: Container(
                                                    decoration: BoxDecoration(
                                                      shape: BoxShape.circle,
                                                      border: Border.all(
                                                        color: isDarkMode
                                                            ? const Color(
                                                                0xFF2A2A2E,
                                                              )
                                                            : Theme.of(context)
                                                                  .colorScheme
                                                                  .primaryContainer,
                                                        width: 1,
                                                      ),
                                                    ),
                                                    child: CircleAvatar(
                                                      radius:
                                                          mutualAvatarRadius,
                                                      backgroundImage: img,
                                                      backgroundColor:
                                                          Theme.of(context)
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
                                        const SizedBox(width: 4),
                                        Flexible(
                                          child: Text(
                                            '+${user.mutualFriends} mutual',
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                            style: AppTextStyles.subText
                                                .copyWith(
                                                  fontSize: mutualFontSize,
                                                  fontWeight: FontWeight.w400,
                                                  color: isDarkMode
                                                      ? Colors.white.withValues(
                                                          alpha: 0.4,
                                                        )
                                                      : const Color(0xFF8E8E8E),
                                                ),
                                          ),
                                        ),
                                      ],
                                    )
                                  else
                                    Text(
                                      '+${user.mutualFriends} Mutuals',
                                      textAlign: TextAlign.center,
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                      style: AppTextStyles.subText.copyWith(
                                        fontSize: mutualFontSize,
                                        fontWeight: FontWeight.w400,
                                        color: isDarkMode
                                            ? Colors.white.withValues(
                                                alpha: 0.4,
                                              )
                                            : const Color(0xFF8E8E8E),
                                      ),
                                    )
                                else
                                  Text(
                                    user.role.isNotEmpty
                                        ? user.role
                                        : '+${user.mutualFriends} Mutuals',
                                    textAlign: TextAlign.center,
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                    style: AppTextStyles.subText.copyWith(
                                      fontSize: mutualFontSize,
                                      fontWeight: FontWeight.w400,
                                      color: isDarkMode
                                          ? Colors.white.withValues(alpha: 0.4)
                                          : const Color(0xFF8E8E8E),
                                    ),
                                  ),

                                // ── Chase Button ──
                                GestureDetector(
                                  onTap: () async {
                                    if (isChased) {
                                      setLocalState(
                                        () => _chasedUserIds.remove(user.id),
                                      );
                                      try {
                                        await apiService.unfriend(user.id);
                                      } catch (e) {
                                        setLocalState(
                                          () => _chasedUserIds.add(user.id),
                                        );
                                      }
                                    } else {
                                      setLocalState(
                                        () => _chasedUserIds.add(user.id),
                                      );
                                      try {
                                        await apiService.sendFriendRequest(
                                          user.username,
                                        );
                                      } catch (e) {
                                        setLocalState(
                                          () => _chasedUserIds.remove(user.id),
                                        );
                                      }
                                    }
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 250),
                                    margin: EdgeInsets.only(
                                      top: buttonTopMargin,
                                    ),
                                    height: buttonHeight,
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      color: isChased
                                          ? Colors.transparent
                                          : Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                      borderRadius: BorderRadius.circular(
                                        AppRadius.button,
                                      ),
                                      border: isChased
                                          ? Border.all(
                                              color: isDarkMode
                                                  ? Colors.white.withValues(
                                                      alpha: 0.3,
                                                    )
                                                  : Theme.of(
                                                      context,
                                                    ).colorScheme.primary,
                                              width: 1,
                                            )
                                          : null,
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        if (!isChased) ...[
                                          Icon(
                                            Icons.add,
                                            color: Colors.white,
                                            size: (itemHeight * 0.07).clamp(
                                              12.0,
                                              16.0,
                                            ),
                                          ),
                                          const SizedBox(width: 3),
                                        ],
                                        Text(
                                          isChased ? 'Chasing' : 'Chase',
                                          style: TextStyle(
                                            color: isChased
                                                ? (isDarkMode
                                                      ? Colors.white.withValues(
                                                          alpha: 0.8,
                                                        )
                                                      : Theme.of(
                                                          context,
                                                        ).colorScheme.primary)
                                                : Colors.white,
                                            fontSize: buttonFontSize.sp,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    }, childCount: _users.length),
                  ),
                ),
                if (_isLoading)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 16.h),
                      child: Center(
                        child: Loader(
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: CommonAppBar(
        title: AppLocalizations.of(context)!.discoverdusers,
        showBackButton: true,
      ),
      body: bodyWidget,
    );
  }
}
