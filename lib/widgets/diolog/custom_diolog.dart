// ignore_for_file: unused_element

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lottie/lottie.dart';

import '../../../core/constants/app_images.dart';
import 'block_user_diolog.dart';
import 'delete_account.dart';
import 'delete_post_diolog.dart';
import 'diolog_animation.dart';
import 'exit_group.dart';
import 'logout_dialog.dart';
import 'notifications_diolog.dart';

// loading diolog
void showLoadingDialog(BuildContext context) {
  diologanimation(
    context,
    Container(
      width: 55.w,
      height: 55.h,
      color: Colors.transparent,
      child: Center(
        child: Lottie.asset(Assets.assetsImagesProgressIndicator, repeat: true),
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

// logout diolog
void showLogoutDiolog(BuildContext context, VoidCallback onTap) {
  diologanimation(context, LogoutDialog(onPressed: onTap));
}

// delete account diolog
void showDeleteAccountDiolog(BuildContext context, VoidCallback onTap) {
  diologanimation(context, DeleteAccountDioloig(onPressed: onTap));
}

// block user diolog
showBlockUserDiolog(BuildContext context, VoidCallback onTap) {
  diologanimation(context, BlockUserDiolog(onPressed: onTap,));
}

// exit group diolog
showExitGroupDiolog(BuildContext context, VoidCallback onTap) {
  diologanimation(context,ExitGroupDiolog(onPressed: onTap));
}
