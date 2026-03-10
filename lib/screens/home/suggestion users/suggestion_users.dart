// ignore_for_file: deprecated_member_use

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:polzet_app/widgets/loader.dart';

import '../../../api/services/api_service.dart';
import '../../../mixin/utility_mixins.dart';
import '../../../models/user/suggestionsb users/suggestions_users_model.dart';
import '../../../widgets/button/back_button.dart';
import '../../../widgets/custom_text_styles.dart';
import '../profile/public/public_profile.dart';

class SuggestionUsers extends StatefulWidget {
  const SuggestionUsers({super.key});

  @override
  State<SuggestionUsers> createState() => _SuggestionUsersState();
}

class _SuggestionUsersState extends State<SuggestionUsers> with UtilityMixin {
  ApiService apiService = ApiService();
  final Set<int> _chasedUserIds = {};
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: const PrimaryBackButton(),
        centerTitle: true,
        title: Text(
          'Discoverd users',
          style: CustomTextStyles.appBarTitleText(context),
        ),
        backgroundColor: Theme.of(context).colorScheme.background,
        surfaceTintColor: Theme.of(context).colorScheme.background,
        toolbarHeight: 25.h,
      ),
      body: FutureBuilder<UserSuggestionsModel>(
        future: apiService.fetchUserSuggestions(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: Loader(color: Theme.of(context).colorScheme.primary),
            );
          }

          if (snapshot.hasError || !snapshot.hasData) {
            return const SizedBox.shrink();
          }

          final users = snapshot.data?.data.peopleYouMayKnow ?? [];
          if (users.isEmpty) return const SizedBox.shrink();

          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, i) {
              final user = users[i];

              ImageProvider buildAvatar() {
                if (user.avatar.startsWith('data:image')) {
                  final base64Str = user.avatar.split(',').last;
                  return MemoryImage(base64Decode(base64Str));
                }
                return NetworkImage(user.avatar);
              }

              return Container(
                height: 40.h,
                width: double.infinity,
                padding: EdgeInsets.symmetric(horizontal: 10.w),
                margin: EdgeInsets.only(
                  bottom: 7.h,
                  right: 10.w,
                  left: 10.w,
                  top: 5.h,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12.r),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1C000000),
                      blurRadius: 5,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: () {
                        navigationPush(context, PublicProfile(userId: user.id));
                      },
                      child: CircleAvatar(
                        radius: 20,
                        backgroundImage: buildAvatar(),
                        backgroundColor: Colors.grey.shade200,
                      ),
                    ),
                    SizedBox(width: 5.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            user.name,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onBackground,
                              fontSize: 10.8.sp,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          Text(
                            '+${user.mutualFriends.toString()} Mutuals',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 9.5.sp,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),

                    StatefulBuilder(
                      builder: (context, setLocalState) {
                        final isChased = _chasedUserIds.contains(user.id);
                        return GestureDetector(
                          onTap: () async {
                            if (isChased) {
                              // Unfriend
                              setLocalState(
                                () => _chasedUserIds.remove(user.id),
                              );
                              try {
                                await apiService.unfriend(user.id);
                              } catch (e) {
                                // Revert on failure
                                setLocalState(
                                  () => _chasedUserIds.add(user.id),
                                );
                              }
                            } else {
                              // Send friend request
                              setLocalState(() => _chasedUserIds.add(user.id));
                              try {
                                await apiService.sendFriendRequest(
                                  user.username,
                                );
                              } catch (e) {
                                // Revert on failure
                                setLocalState(
                                  () => _chasedUserIds.remove(user.id),
                                );
                              }
                            }
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            height: 20.h,
                            width: 80.w,
                            margin: EdgeInsets.only(left: 10.w),
                            decoration: BoxDecoration(
                              color: isChased
                                  ? Colors.grey.shade400
                                  : Theme.of(context).colorScheme.primary,
                              borderRadius: BorderRadius.circular(25.r),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (!isChased) ...[
                                  Icon(
                                    Icons.add,
                                    color: Colors.white,
                                    size: 16.sp,
                                  ),
                                  SizedBox(width: 3.w),
                                ],
                                Text(
                                  isChased ? 'Chased' : 'Chase',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10.8.sp,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
