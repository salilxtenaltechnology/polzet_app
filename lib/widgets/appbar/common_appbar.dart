// common_app_bar.dart

// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../core/constants/app_constants.dart';
import '../../core/themes/app_text_styles.dart';
import '../button/back_button.dart';

class CommonAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool showBackButton;
  final List<Widget>? actions;

  const CommonAppBar({
    super.key,
    required this.title,
    this.showBackButton = true,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      leading: showBackButton
          ? Padding(
              padding: EdgeInsets.only(left: 8.w),
              child: const PrimaryBackButton(),
            )
          : null,
      leadingWidth: showBackButton ? 48.w : 0,
      centerTitle: false,
      titleSpacing: showBackButton ? 4.w : 10.w,
      title: Text(
        title,
        style: AppTextStyles.pageTitleTextStyle(
          context,
        ).copyWith(fontSize: 17.sp),
      ),
      backgroundColor: Theme.of(context).colorScheme.background,
      surfaceTintColor: Theme.of(context).colorScheme.background,
      toolbarHeight: AppConstants.toolbarHeight.h,
      actions: actions,
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(35.h);
}
