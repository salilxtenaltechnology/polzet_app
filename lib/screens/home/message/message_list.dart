// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_images.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../mixin/utility_mixins.dart';
import '../../../widgets/custom_text_styles.dart';
import 'chat/chat_screen.dart';

class MessageList extends StatefulWidget {
  const MessageList({super.key});

  @override
  State<MessageList> createState() => _MessageListState();
}

class _MessageListState extends State<MessageList> with UtilityMixin {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        toolbarHeight: 25.h,
        leading: GestureDetector(
          onTap: () {
            Navigator.pop(context);
          },
          child: const Icon(Icons.arrow_back_ios),
        ),
        title: Text(
          AppLocalizations.of(context)!.messages,
          style: CustomTextStyles.appBarTitleText(context),
        ),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.background,
        surfaceTintColor: Theme.of(context).colorScheme.background,
      ),
      body: ListView(
        padding: EdgeInsets.symmetric(horizontal: 10.w),
        children: [
          ListTile(
            onTap: () {
              navigationPush(context, ChatScreen(memberName: 'Samuel Garry'));
            },
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              radius: 24,
              backgroundColor: Colors.grey[700],
              backgroundImage: const AssetImage(Assets.assetsImagesPeople3),
            ),
            title: Text(
              'Samuel Garry',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onBackground,
                fontSize: 11.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              'Just sent the design, feel thi lemme join ur club, buddy',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: CustomTextStyles.msgAuthTitleText(context),
            ),
            trailing: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Yesterday',
                  style: TextStyle(
                    fontSize: 8.5.sp,
                    color: const Color(0XFF999999),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(5).w,
                  decoration: const BoxDecoration(
                    color: AppColors.primaryColor,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '5',
                    style: TextStyle(fontSize: 8.sp, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            onTap: () {
              navigationPush(
                context,
                ChatScreen(memberName: 'Margareth Joanne'),
              );
            },
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              radius: 24,
              backgroundColor: Colors.grey[700],
              backgroundImage: const AssetImage(Assets.assetsImagesPeople4),
            ),
            title: Text(
              'Margareth Joanne',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onBackground,
                fontSize: 11.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              'Whats up Sam, it’s Frankie.😏',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: CustomTextStyles.msgAuthTitleText(context),
            ),
            trailing: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '07/18/2022',
                  style: TextStyle(
                    fontSize: 8.5.sp,
                    color: const Color(0XFF999999),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(5).w,
                  decoration: const BoxDecoration(
                    color: AppColors.primaryColor,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '3',
                    style: TextStyle(fontSize: 8.sp, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
