// ignore_for_file: unused_element

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lottie/lottie.dart';

import '../../gen/assets.gen.dart';
import 'block_user_diolog.dart';
import 'business/switch_business_acc_diolog.dart';
import 'clear_search_history_diolog.dart';
import 'confirm_deletion_account_diolog.dart';
import 'crop_image_diolog.dart';
import 'delete_account.dart';
import 'delete_comment_diolog.dart';
import 'delete_group.dart';
import 'delete_post_diolog.dart';
import 'diolog_animation.dart';
import 'leave_group.dart';
import 'logout_dialog.dart';
import 'notifications_diolog.dart';
import 'report_chat_diolog.dart';

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

// user delete post diolog
void showUserDeletePostDiolog(BuildContext context, VoidCallback onTap) {
  diologanimation(context, DeletePostDiolog(onPressed: onTap));
}

// crop image diolog
Future<bool?> cropImageDiolog(BuildContext context) {
  return diologanimation<bool>(context, const CropImageDiolog());
}

// crop image diolog
void searchHistoryDiolog(BuildContext context, VoidCallback onTap) {
  diologanimation(context, ClearSearchHistoryDiolog(onPressed: onTap));
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

// delete account diolog
void showDeleteAccountDiolog(BuildContext context, VoidCallback onTap) {
  diologanimation(context, DeleteAccountDioloig(onPressed: onTap));
}

// confirm delete account diolog
void showConfirmDeletionAccountDiolog(
  BuildContext context,
  Function(String password) onTap,
) {
  diologanimation(context, ConfirmDeletionAccountDioloig(onPressed: onTap));
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
