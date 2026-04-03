// ✅ Add this as a separate widget outside Dashboard class
// ignore_for_file: deprecated_member_use

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../api/services/api_service.dart';
import '../../../mixin/utility_mixins.dart';
import '../../../models/user/suggestionsb users/suggestions_users_model.dart';
import '../../../widgets/shimmer/suggestion_users_shimmer.dart';
import '../profile/public/public_profile.dart';

import '../../../widgets/error/api_error_widget.dart';

class PeopleYouMayKnowSection extends StatefulWidget {
  final Future<UserSuggestionsModel> suggestionsFuture;
  final Set<int> chasedUserIds;
  final ApiService apiService;

  const PeopleYouMayKnowSection({
    super.key,
    required this.suggestionsFuture,
    required this.chasedUserIds,
    required this.apiService,
  });

  @override
  State<PeopleYouMayKnowSection> createState() =>
      _PeopleYouMayKnowSectionState();
}

class _PeopleYouMayKnowSectionState extends State<PeopleYouMayKnowSection>
    with UtilityMixin {
  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

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
          height: 210,
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
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(
                            isDarkMode ? 0.3 : 0.05,
                          ),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        GestureDetector(
                          onTap: () => navigationPush(
                            context,
                            PublicProfile(userId: user.id),
                          ),
                          child: CircleAvatar(
                            radius: 23,
                            backgroundImage: buildAvatar(),
                            backgroundColor: Colors.grey.shade200,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          user.name,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onBackground,
                            fontSize: 10.3.sp,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          user.role,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: const TextStyle(
                            color: Color.fromARGB(255, 180, 179, 179),
                            fontSize: 10.3,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '+${user.mutualFriends} Mutuals',
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onBackground,
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w500,
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
                            margin: const EdgeInsets.only(top: 12),
                            height: 25.h,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: isChased
                                  ? Colors.grey.shade400
                                  : Theme.of(context).colorScheme.primary,
                              borderRadius: BorderRadius.circular(25),
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
                                  isChased ? 'Chased' : 'Chase',
                                  style:  TextStyle(
                                    color: Colors.white,
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
