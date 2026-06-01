// ignore_for_file: deprecated_member_use

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_radius.dart';
import '../../../../core/themes/app_text_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../gen/assets.gen.dart';
import '../../../../languages/l10n/generated/app_localizations.dart';
import '../../../../widgets/appbar/common_appbar.dart';
import '../../../../widgets/dialog/custom_diolog.dart';

class NotificationsSettings extends StatefulWidget {
  const NotificationsSettings({super.key});

  @override
  State<NotificationsSettings> createState() => _NotificationsSettingsState();
}

class _NotificationsSettingsState extends State<NotificationsSettings> {
  bool isMuteNotifications = false;
  bool pollActivity = false;
  bool commentsAndReplies = false;
  bool commentsPosts = false;
  bool message = false;
  bool socialActivity = false;
  bool mentionsandtags = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: CommonAppBar(
        title: AppLocalizations.of(context)!.notifications,
        showBackButton: true,
      ),

      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12.w),
        child: Column(
          children: [
            _buildPushNotificationsCard(isMuteNotifications, (value) {
              setState(() {
                isMuteNotifications = value;
                if (!value) {
                  pollActivity = false;
                  commentsAndReplies = false;
                  commentsPosts = false;
                  message = false;
                  socialActivity = false;
                  mentionsandtags = false;
                }
              });
            }),
            SizedBox(height: 20.h),
            _labelModel(
              AppLocalizations.of(context)!.pollactivity,
              pollActivity,
              isMuteNotifications
                  ? (value) {
                      setState(() {
                        if (value == false) {
                          showNotificationTimerDiolog(context, () {
                            pollActivity = value;
                          });
                        }
                        pollActivity = value;
                      });
                    }
                  : null, // null disables the CupertinoSwitch
            ),
            SizedBox(height: 10.h),
            _labelModel(
              AppLocalizations.of(context)!.commentsandreplies,
              commentsAndReplies,
              isMuteNotifications
                  ? (value) {
                      setState(() {
                        if (value == false) {
                          showNotificationTimerDiolog(context, () {
                            commentsAndReplies = value;
                          });
                        }
                        commentsAndReplies = value;
                      });
                    }
                  : null,
            ),
            SizedBox(height: 10.h),
            _labelModel(
              AppLocalizations.of(context)!.message,
              message,
              isMuteNotifications
                  ? (value) {
                      setState(() {
                        if (value == false) {
                          showNotificationTimerDiolog(context, () {
                            message = value;
                          });
                        }
                        message = value;
                      });
                    }
                  : null,
            ),
            SizedBox(height: 10.h),
            _labelModel(
              AppLocalizations.of(context)!.socialactivity,
              socialActivity,
              isMuteNotifications
                  ? (value) {
                      setState(() {
                        if (value == false) {
                          showNotificationTimerDiolog(context, () {
                            socialActivity = value;
                          });
                        }
                        socialActivity = value;
                      });
                    }
                  : null,
            ),
            SizedBox(height: 10.h),
            _labelModel(
              AppLocalizations.of(context)!.mentionsandtags,
              mentionsandtags,
              isMuteNotifications
                  ? (value) {
                      setState(() {
                        if (value == false) {
                          showNotificationTimerDiolog(context, () {
                            mentionsandtags = value;
                          });
                        }
                        mentionsandtags = value;
                      });
                    }
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPushNotificationsCard(
    bool isSwitch,
    ValueChanged<bool>? onChanged,
  ) {
    final txt = AppTextColors.of(context);
    return Container(
      margin: const EdgeInsets.only(top: 5),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline,
          width: 1,
        ),
        boxShadow: const [BoxShadow(color: Color(0x06000000), blurRadius: 2)],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Container(
              height: 47,
              width: 47,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Image.asset(
                Assets.images.inactiveBell.path,
                color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.7),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context)!.pushnotification,
                    style: AppTextStyles.bodyText.copyWith(
                      color: txt.title,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 3.h),
                  Text(
                    AppLocalizations.of(
                      context,
                    )!.receivealertandupdatesacrosspolzet,

                    style: AppTextStyles.subText.copyWith(
                      color: txt.muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            Transform.scale(
              scale: 0.85,
              child: CupertinoSwitch(
                activeTrackColor: AppColors.primaryColor,
                value: isSwitch,
                onChanged: onChanged,
              ),
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
    final txt = AppTextColors.of(context);
    return Opacity(
      opacity: onChanged == null ? 0.4 : 1.0,
      child: SizedBox(
        height: 30,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                labelName,
                style: AppTextStyles.bodyText.copyWith(
                  fontSize: 13.5,
                  color: txt.title,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Transform.scale(
              scale: 0.85,
              child: CupertinoSwitch(
                activeTrackColor: AppColors.primaryColor,
                value: isSwitch,
                onChanged: onChanged,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
