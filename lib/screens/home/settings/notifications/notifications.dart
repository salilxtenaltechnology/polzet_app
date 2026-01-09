// ignore_for_file: deprecated_member_use

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../widgets/custom_text_styles.dart';
import '../../../../widgets/diolog/custom_diolog.dart';

class NotificationsSettings extends StatefulWidget {
  const NotificationsSettings({super.key});

  @override
  State<NotificationsSettings> createState() => _NotificationsSettingsState();
}

class _NotificationsSettingsState extends State<NotificationsSettings> {
  bool isMuteNotifications = false;
  bool appNotification = false;
  bool likePosts = false;
  bool commentsPosts = false;
  bool message = false;
  bool newFollowers = false;
  bool mentionsandtags = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        toolbarHeight: 25.h,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Icon(Icons.arrow_back_ios),
        ),
        title: Text(
          AppLocalizations.of(context)!.notifications,
          style: CustomTextStyles.appBarTitleText(context),
        ),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.background,
      ),
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12.w),
        child: Column(
          children: [
            _labelModel(
              AppLocalizations.of(context)!.mutenotifications,
              isMuteNotifications,
              (value) {
                setState(() {
                  isMuteNotifications = value;
                });
              },
            ),
            Divider(
              thickness: 1,
              height: 30,
              color: Theme.of(
                context,
              ).colorScheme.onBackground.withOpacity(0.1),
            ),
            _labelModel(
              AppLocalizations.of(context)!.appnotification,
              appNotification,
              (value) {
                setState(() {
                  if (value == false) {
                    showNotificationTimerDiolog(context, () {
                      appNotification = value;
                    });
                  }
                  appNotification = value;
                });
              },
            ),
            SizedBox(height: 10.h),
            _labelModel(
              AppLocalizations.of(context)!.likeonyourposts,
              likePosts,
              (value) {
                setState(() {
                  if (value == false) {
                    showNotificationTimerDiolog(context, () {
                      likePosts = value;
                    });
                  }
                  likePosts = value;
                });
              },
            ),
            SizedBox(height: 10.h),
            _labelModel(
              AppLocalizations.of(context)!.commentsonyourposts,
              commentsPosts,
              (value) {
                setState(() {
                  if (value == false) {
                    showNotificationTimerDiolog(context, () {
                      commentsPosts = value;
                    });
                  }
                  commentsPosts = value;
                });
              },
            ),
            SizedBox(height: 10.h),
            _labelModel(AppLocalizations.of(context)!.message, message, (
              value,
            ) {
              setState(() {
                if (value == false) {
                  showNotificationTimerDiolog(context, () {
                    message = value;
                  });
                }
                message = value;
              });
            }),
            SizedBox(height: 10.h),
            _labelModel(AppLocalizations.of(context)!.newvibe, newFollowers, (
              value,
            ) {
              setState(() {
                if (value == false) {
                  showNotificationTimerDiolog(context, () {
                    newFollowers = value;
                  });
                }
                newFollowers = value;
              });
            }),
            SizedBox(height: 10.h),
            _labelModel(
              AppLocalizations.of(context)!.mentionsandtags,
              mentionsandtags,
              (value) {
                setState(() {
                  if (value == false) {
                    showNotificationTimerDiolog(context, () {
                      mentionsandtags = value;
                    });
                  }
                  mentionsandtags = value;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _labelModel(
    String labelName,
    bool isSwitch,
    ValueChanged<bool>? onChanged,
  ) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    labelName,
                    style: CustomTextStyles.lblPrimaryText(context),
                  ),
                ],
              ),
            ),
            Transform.scale(
              scale: 0.85,
              child: CupertinoSwitch(
                activeTrackColor: AppColors.primaryColor,
                value: isSwitch,
                onChanged: onChanged, // Use the parameter here
              ),
            ),
          ],
        ),
      ],
    );
  }
}
