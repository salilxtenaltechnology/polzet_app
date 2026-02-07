// ignore_for_file: deprecated_member_use, must_be_immutable

import 'package:feather_icons/feather_icons.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/constants/app_images.dart';
import '../../../../mixin/utility_mixins.dart';
import '../../../../widgets/custom_text_styles.dart';
import '../../../../widgets/diolog/custom_diolog.dart';
import '../media/media_screen.dart';

class ChatDetails extends StatefulWidget {
  String? memberName;
  ChatDetails({super.key, required this.memberName});

  @override
  State<ChatDetails> createState() => _ChatDetailsState();
}

class _ChatDetailsState extends State<ChatDetails> with UtilityMixin {
  bool _isMuteNotification = false;
  bool _isProtectedChat = false;
  bool _isHideChat = false;
  bool _isHideChatHistory = false;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: GestureDetector(
          onTap: () {
            Navigator.pop(context);
          },
          child: const Icon(Icons.arrow_back_ios),
        ),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.background,
        surfaceTintColor: Theme.of(context).colorScheme.background,
        actions: [
          Icon(FeatherIcons.video, size: 20.sp),
          SizedBox(width: 15.w),
          Icon(FeatherIcons.phone, size: 18.sp),
          SizedBox(width: 15.w),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12.w),
        child: Column(
          children: [
            SizedBox(
              height: 90.h,
              width: 90.w,
              child: Stack(
                children: [
                  Container(
                    margin: EdgeInsets.only(bottom: 10.h),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Theme.of(
                          context,
                        ).colorScheme.onBackground.withOpacity(0.1),
                        width: 1.w,
                      ),
                      image: const DecorationImage(
                        image: AssetImage(Assets.assetsImagesIcUser),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  widget.memberName!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onBackground,
                    fontSize: 14.5.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            SizedBox(height: 10.h),
            Divider(
              thickness: 1,
              color: Theme.of(
                context,
              ).colorScheme.onBackground.withOpacity(0.1),
            ),
            Padding(
              padding: EdgeInsets.only(top: 10.h),
              child: GestureDetector(
                onTap: () {
                  navigationPush(
                    context,
                    MediaScreen(memberName: widget.memberName!),
                  );
                },
                child: Row(
                  children: [
                    Icon(FeatherIcons.image, size: 20.spMax),
                    SizedBox(width: 8.w),
                    Text(
                      'Media, Links & Documents',
                      style: CustomTextStyles.lblContentText(context),
                    ),
                    const Spacer(),
                    Text(
                      '155',
                      style: CustomTextStyles.lblContentText(context),
                    ),
                    SizedBox(width: 10.w),
                    Icon(
                      FeatherIcons.chevronRight,
                      color: Theme.of(
                        context,
                      ).colorScheme.onBackground.withOpacity(0.5),
                      size: 20.spMax,
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(top: 15.h),
              child: Row(
                children: [
                  Icon(FeatherIcons.volume2, size: 20.spMax),
                  SizedBox(width: 8.w),
                  Text(
                    'Mute Notification',
                    style: CustomTextStyles.lblContentText(context),
                  ),
                  const Spacer(),
                  Container(
                    color: Colors.white,
                    width: 35.w,
                    height: 20.h,
                    child: Transform.scale(
                      scale: 0.75,
                      child: CupertinoSwitch(
                        activeTrackColor: AppColors.primaryColor,
                        value: _isMuteNotification,
                        onChanged: (value) =>
                            setState(() => _isMuteNotification = value),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.only(top: 15.h),
              child: Row(
                children: [
                  Icon(FeatherIcons.bell, size: 19.spMax),
                  SizedBox(width: 8.w),
                  Text(
                    'Custom Notification',
                    style: CustomTextStyles.lblContentText(context),
                  ),
                  const Spacer(),
                  Icon(
                    FeatherIcons.chevronRight,
                    color: Theme.of(
                      context,
                    ).colorScheme.onBackground.withOpacity(0.5),
                    size: 20.spMax,
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.only(top: 15.h),
              child: Row(
                children: [
                  Icon(FeatherIcons.shield, size: 19.spMax),
                  SizedBox(width: 8.w),
                  Text(
                    'Protected Chat',
                    style: CustomTextStyles.lblContentText(context),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: 30.w,
                    height: 20.h,
                    child: Transform.scale(
                      scale: 0.75,
                      child: CupertinoSwitch(
                        activeTrackColor: AppColors.primaryColor,
                        value: _isProtectedChat,
                        onChanged: (value) =>
                            setState(() => _isProtectedChat = value),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.only(top: 15.h),
              child: Row(
                children: [
                  Icon(FeatherIcons.eye, size: 19.spMax),
                  SizedBox(width: 8.w),
                  Text(
                    'Hide Chat',
                    style: CustomTextStyles.lblContentText(context),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: 30.w,
                    height: 20.h,
                    child: Transform.scale(
                      scale: 0.75,
                      child: CupertinoSwitch(
                        activeTrackColor: AppColors.primaryColor,
                        value: _isHideChat,
                        onChanged: (value) =>
                            setState(() => _isHideChat = value),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.only(top: 15.h),
              child: Row(
                children: [
                  Icon(FeatherIcons.eye, size: 19.spMax),
                  SizedBox(width: 8.w),
                  Text(
                    'Hide Chat History',
                    style: CustomTextStyles.lblContentText(context),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: 30.w,
                    height: 20.h,
                    child: Transform.scale(
                      scale: 0.75,
                      child: CupertinoSwitch(
                        activeTrackColor: AppColors.primaryColor,
                        value: _isHideChatHistory,
                        onChanged: (value) =>
                            setState(() => _isHideChatHistory = value),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.only(top: 15.h),
              child: Row(
                children: [
                  Icon(Icons.color_lens_outlined, size: 19.spMax),
                  SizedBox(width: 8.w),
                  Text(
                    'Custom Color Chat',
                    style: CustomTextStyles.lblContentText(context),
                  ),
                  const Spacer(),
                  Container(
                    height: 18.h,
                    width: 20.w,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(5.r),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.only(top: 15.h),
              child: Row(
                children: [
                  Icon(FeatherIcons.image, size: 19.spMax),
                  SizedBox(width: 8.w),
                  Text(
                    'Custom Background Chat',
                    style: CustomTextStyles.lblContentText(context),
                  ),
                  const Spacer(),
                  Container(
                    height: 18.h,
                    width: 20.w,
                    decoration: BoxDecoration(
                      color: const Color(0XFFF0F0F3),
                      borderRadius: BorderRadius.circular(5.r),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.only(top: 15.h),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_outlined,
                    size: 19.spMax,
                    color: const Color(0XFFF44336),
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    'Report',
                    style: TextStyle(
                      color: const Color(0XFFF44336),
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.only(top: 15.h),
              child: GestureDetector(
                onTap: () {
                  showBlockUserDiolog(context, () {
                    Navigator.pop(context);
                  });
                },
                child: Row(
                  children: [
                    Icon(
                      Icons.block,
                      size: 19.spMax,
                      color: const Color(0XFFF44336),
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      'Block',
                      style: TextStyle(
                        color: const Color(0XFFF44336),
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
