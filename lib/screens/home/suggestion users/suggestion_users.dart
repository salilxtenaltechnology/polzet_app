// ignore_for_file: deprecated_member_use

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:polzet_app/widgets/loader.dart';

import '../../../api/services/api_service.dart';
import '../../../core/constants/app_radius.dart';
import '../../../core/themes/app_text_styles.dart';
import '../../../languages/l10n/generated/app_localizations.dart';
import '../../../mixin/utility_mixins.dart';
import '../../../models/user/suggestionsb users/suggestions_users_model.dart';
import '../../../widgets/button/back_button.dart';
import '../../../widgets/custom_text_styles.dart';

import '../../../widgets/error/api_error_widget.dart';
import '../profile/public/public_profile_screen.dart';

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
          AppLocalizations.of(context)!.discoverdusers,
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

          if (snapshot.hasError) {
            return ApiErrorWidget(onRetry: () => setState(() {}));
          }

          if (!snapshot.hasData) return const SizedBox.shrink();

          final users = snapshot.data?.data.peopleYouMayKnow ?? [];
          if (users.isEmpty) return const SizedBox.shrink();

          return ListView.builder(
            padding: EdgeInsets.only(top: 10.h),
            itemCount: users.length,
            itemBuilder: (context, i) {
              final user = users[i];

              ImageProvider buildAvatar() {
                if (user.avatar.startsWith('data:image')) {
                  return MemoryImage(base64Decode(user.avatar.split(',').last));
                }
                return NetworkImage(user.avatar);
              }

              return Container(
                height: 60,
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                margin: EdgeInsets.only(
                  bottom: 7.h,
                  right: 10.w,
                  left: 10.w,
                  top: 5.h,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  border: Border.all(color: const Color(0XFFEFEFEF), width: 1),
                  boxShadow: const [
                    BoxShadow(color: Color(0x06000000), blurRadius: 2),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: () {
                        navigationPush(
                          context,
                          PublicProfileScreen(userId: user.id),
                        );
                      },
                      child: user.avatar.isNotEmpty
                          ? CircleAvatar(
                              radius: 20,
                              backgroundImage: buildAvatar(),
                              backgroundColor: Colors.grey.shade200,
                            )
                          : CircleAvatar(
                              radius: 20,
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.primary.withOpacity(0.1),
                              child: Text(
                                user.username.isNotEmpty
                                    ? user.username[0].toUpperCase()
                                    : '?',
                                style: TextStyle(
                                  fontSize: 15.sp,
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
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
                            style: AppTextStyles.bodyText.copyWith(
                              color: Theme.of(context).colorScheme.onBackground,
                              fontSize: 14.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            '+${user.mutualFriends.toString()} Mutuals',
                            style: AppTextStyles.bodyText.copyWith(
                              fontSize: 12.5,
                              color: const Color(0XFF8E8E8E),
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
                            duration: const Duration(milliseconds: 200),
                            height: 32,
                            width: 80.w,
                            margin: EdgeInsets.only(left: 10.w),
                            decoration: BoxDecoration(
                              color: isChased
                                  ? Colors.grey.shade400
                                  : Theme.of(context).colorScheme.primary,
                              borderRadius: BorderRadius.circular(
                                AppRadius.button,
                              ),
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
                                  isChased ? 'Chasing' : 'Chase',
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
