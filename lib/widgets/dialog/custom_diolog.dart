// ignore_for_file: unused_element

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lottie/lottie.dart';

import '../../gen/assets.gen.dart';
import 'anonymous_poll/add_anonymous_poll.dart';
import 'block_user_diolog.dart';
import 'business/switch_business_acc_diolog.dart';
import 'crop_image_diolog.dart';
import 'delete_comment_diolog.dart';
import 'delete_group.dart';
import 'delete_post_diolog.dart';
import 'diolog_animation.dart';
import 'leave_group.dart';
import 'logout_dialog.dart';
import 'notifications/clear_all_notifications_diolog.dart';
import 'notifications/delete_notifications_diolog.dart';
import 'notifications_diolog.dart';
import 'pin_security_diolog.dart';
import 'report_chat_diolog.dart';
import 'message/delete_chat_diolog.dart';
import 'message/clear_chat_diolog.dart';
import 'message/delete_message_diolog.dart';

// loading diolog
void showLoadingDialog(BuildContext context) {
  diologanimation(
    context,
    Container(
      width: 55.w,
      height: 55.h,
      color: Colors.transparent,
      child: Center(
        child: Lottie.asset(Assets.images.progressIndicator, repeat: true),
      ),
    ),
  );
}

// notification timer diolog
void showNotificationTimerDiolog(BuildContext context, VoidCallback onTap) {
  diologanimation(context, NotificationsDiolog(onPressed: onTap));
}

// clear all notifications diolog
void showClearAllNotificationsDiolog(BuildContext context, VoidCallback onTap) {
  diologanimation(context, ClearAllNotificationsDialog(onPressed: onTap));
}

// delete notifications diolog
Future<bool?> showDeleteNotificationsDiolog(BuildContext context) {
  return diologanimation<bool>(context, const DeleteNotificationsDialog());
}

// user delete post diolog
void showUserDeletePostDiolog(BuildContext context, VoidCallback onTap) {
  diologanimation(context, DeletePostDiolog(onPressed: onTap));
}

// crop image diolog
Future<bool?> cropImageDiolog(BuildContext context) {
  return diologanimation<bool>(context, const CropImageDiolog());
}

// crop image diolog
// void searchHistoryDiolog(BuildContext context, VoidCallback onTap) {
//   diologanimation(context, ClearSearchHistoryDiolog(onPressed: onTap));
// }

void showAnonymousPollOption(
  BuildContext context,
  VoidCallback onTapThings,
  VoidCallback onTapImage,
) {
  diologanimation(
    context,
    AddAnonymousPoll(onPressedThings: onTapThings, onPressedImage: onTapImage),
  );
}

// delete comment diolog
void showDeleteCommentDiolog(BuildContext context, VoidCallback onTap) {
  diologanimation(context, DeleteCommentDiolog(onPressed: onTap));
}

// switch to business diolog
void showSwitchToBusinessDiolog(BuildContext context, VoidCallback onTap) {
  diologanimation(context, SwithBusinessAccDiolog(onPressed: onTap));
}

// logout diolog
void showLogoutDiolog(BuildContext context, VoidCallback onTap) {
  diologanimation(context, LogoutDialog(onPressed: onTap));
}

// block user diolog
showBlockUserDiolog(BuildContext context, VoidCallback onTap, bool isBlock) {
  diologanimation(
    context,
    BlockUserDiolog(onPressed: onTap, isUserBlock: isBlock),
  );
}

// leave group diolog
showLeaveGroupDiolog(BuildContext context, VoidCallback onTap) {
  diologanimation(context, LeaveGroupDialog(onPressed: onTap));
}

// delete group diolog
showDeleteGroupDiolog(BuildContext context, VoidCallback onTap) {
  diologanimation(context, DeleteGroupDiolog(onPressed: onTap));
}

// delete group diolog
showReportChatDiolog(BuildContext context, VoidCallback onTap) {
  diologanimation(context, ReportChatDiolog(onPressed: onTap));
}

// PIN security diolog
showPinSecurityDiolog(
  BuildContext context,
  String titile,
  String diologMessage,
  VoidCallback onTap,
) {
  diologanimation(
    context,
    PinSecurityDiolog(
      title: titile,
      diologMessage: diologMessage,
      onPressed: onTap,
    ),
  );
}

// delete chat diolog
void showDeleteChatDiolog(BuildContext context, VoidCallback onTap) {
  diologanimation(context, DeleteChatDiolog(onPressed: onTap));
}

// clear chat diolog
void showClearChatDiolog(BuildContext context, VoidCallback onTap) {
  diologanimation(context, ClearChatDiolog(onPressed: onTap));
}

// delete message diolog
void showDeleteMessageDialog(BuildContext context, VoidCallback onTap) {
  diologanimation(context, DeleteMessageDialog(onPressed: onTap));
}

