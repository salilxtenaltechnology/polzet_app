// ignore_for_file: deprecated_member_use
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:polzet_app/core/themes/app_text_styles.dart';

import '../../../api/services/api_service.dart';
import '../../../core/constants/app_radius.dart';
import '../../../core/themes/app_text_colors.dart';
import '../../../mixin/utility_mixins.dart';
import '../../../models/user/suggestionsb users/suggestions_users_model.dart';
import '../../../widgets/shimmer/suggestion_users_shimmer.dart';
import '../../../widgets/error/api_error_widget.dart';
import '../profile/public/public_profile_screen.dart';

class SuggestedUsers extends StatefulWidget {
  final Future<UserSuggestionsModel> suggestionsFuture;
  final Set<dynamic> chasedUserIds;
  final ApiService apiService;

  const SuggestedUsers({
    super.key,
    required this.suggestionsFuture,
    required this.chasedUserIds,
    required this.apiService,
  });

  @override
  State<SuggestedUsers> createState() => _SuggestedUsersState();
}

class _SuggestedUsersState extends State<SuggestedUsers> with UtilityMixin {
  @override
  Widget build(BuildContext context) {
    final txt = AppTextColors.of(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return FutureBuilder<UserSuggestionsModel>(
      future: widget.suggestionsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SizedBox(
            height: 200,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: 5,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, __) => const ShimmerUserCard(),
            ),
          );
        }

        if (snapshot.hasError) {
          debugPrint('❌ Error: ${snapshot.error}');
          return const SizedBox(
            height: 200,
            child: ApiErrorWidget(
              title: 'Unexpected Error',
              subtitle: 'Could not load suggested users',
            ),
          );
        }

        if (!snapshot.hasData) return const SizedBox.shrink();

        final users = snapshot.data?.data.peopleYouMayKnow ?? [];
        if (users.isEmpty) return const SizedBox.shrink();

        final double cardWidth =
            (MediaQuery.of(context).size.width - 16 * 2 - 12) / 2;

        return SizedBox(
          height: 250,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            itemCount: users.length > 5 ? 5 : users.length,
            itemBuilder: (context, i) {
              final user = users[i];

              ImageProvider buildAvatar() {
                if (user.avatar.startsWith('data:image')) {
                  return MemoryImage(base64Decode(user.avatar.split(',').last));
                }
                return NetworkImage(user.avatar);
              }

              return StatefulBuilder(
                builder: (context, setLocalState) {
                  final isChased = widget.chasedUserIds.contains(user.id);

                  return Container(
                    width: cardWidth,
                    margin: const EdgeInsets.only(right: 12, top: 7),
                    padding: const EdgeInsets.symmetric(
                      vertical: 20,
                      horizontal: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(AppRadius.card),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline,
                        width: 1,
                      ),
                      boxShadow: const [
                        BoxShadow(color: Color(0x06000000), blurRadius: 2),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        GestureDetector(
                          onTap: () => navigationPush(
                            context,
                            PublicProfileScreen(userId: user.id.toString()),
                          ),
                          child: user.avatar.isNotEmpty
                              ? CircleAvatar(
                                  radius: 50,
                                  backgroundImage: buildAvatar(),
                                  backgroundColor: Colors.grey.shade200,
                                )
                              : CircleAvatar(
                                  radius: 50,
                                  backgroundColor: isDarkMode
                                      ? Colors.grey.withOpacity(0.1)
                                      : Theme.of(
                                          context,
                                        ).colorScheme.primary.withOpacity(0.1),
                                  child: Text(
                                    user.username.isNotEmpty
                                        ? user.username[0].toUpperCase()
                                        : '?',
                                    style: TextStyle(
                                      fontSize: 30.sp,
                                      fontWeight: FontWeight.w600,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onPrimary.withOpacity(0.8),
                                    ),
                                  ),
                                ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          user.name,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: AppTextStyles.bodyText.copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onBackground,
                          ),
                        ),
                        const SizedBox(height: 5),
                        if (user.mutualFriendsAvatars.isNotEmpty)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                height: 20,
                                width: (user.mutualFriendsAvatars.take(3).length - 1) * 14.0 + 18.0,
                                child: Stack(
                                  children: List.generate(
                                    user.mutualFriendsAvatars.take(3).length,
                                    (index) {
                                      final avatarUrl = user.mutualFriendsAvatars[index];
                                      ImageProvider img;
                                      if (avatarUrl.startsWith('data:image')) {
                                        img = MemoryImage(
                                          base64Decode(avatarUrl.split(',').last),
                                        );
                                      } else {
                                        img = NetworkImage(avatarUrl);
                                      }
                                      return Positioned(
                                        left: index * 14.0,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: isDarkMode
                                                  ? const Color(0xFF2A2A2E)
                                                  : Theme.of(context).colorScheme.primaryContainer,
                                              width: 1,
                                            ),
                                          ),
                                          child: CircleAvatar(
                                            radius: 9,
                                            backgroundImage: img,
                                            backgroundColor: Colors.grey.shade200,
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
                                  style: AppTextStyles.subText.copyWith(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w400,
                                    color: txt.muted,
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
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              color: txt.muted,
                            ),
                          ),

                        GestureDetector(
                          onTap: () async {
                            if (isChased) {
                              setLocalState(
                                () => widget.chasedUserIds.remove(user.id),
                              );
                              try {
                                await widget.apiService.unfriend(user.id);
                              } catch (e) {
                                setLocalState(
                                  () => widget.chasedUserIds.add(user.id),
                                );
                              }
                            } else {
                              setLocalState(
                                () => widget.chasedUserIds.add(user.id),
                              );
                              try {
                                await widget.apiService.sendFriendRequest(
                                  user.username,
                                );
                              } catch (e) {
                                setLocalState(
                                  () => widget.chasedUserIds.remove(user.id),
                                );
                              }
                            }
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            margin: const EdgeInsets.only(top: 15),
                            height: 32,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: isChased
                                  ? Colors.transparent
                                  : Theme.of(context).colorScheme.primary,
                              borderRadius: BorderRadius.circular(
                                AppRadius.button,
                              ),
                              border: isChased
                                  ? Border.all(
                                      color: isDarkMode
                                          ? Theme.of(context)
                                                .colorScheme
                                                .onPrimary
                                                .withOpacity(0.3)
                                          : Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                      width: 1,
                                    )
                                  : null,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (!isChased) ...[
                                  const Icon(
                                    Icons.add,
                                    color: Colors.white,
                                    size: 16,
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
                                    fontSize: 10.8.sp,
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
            },
          ),
        );
      },
    );
  }
}
