// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class NotificationsDiolog extends StatelessWidget {
  const NotificationsDiolog({super.key, required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
        width: 270.w,
        margin: EdgeInsets.symmetric(horizontal: 40.w),
        padding: EdgeInsets.fromLTRB(0, 10.h, 0, 10.h),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              _label(context, '1 Hours', () {
                Navigator.pop(context);
              }),
              _primaryDivider(context),
              _label(context, '8 Hours', () {
                Navigator.pop(context);
              }),
              _primaryDivider(context),
              _label(context, '24 Hours', () {
                Navigator.pop(context);
              }),
              _primaryDivider(context),
              _label(context, '7 Days', () {
                Navigator.pop(context);
              }),
            ]));
  }

  Widget _label(BuildContext context, String text, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Text(text,
          style: TextStyle(
              color: Theme.of(context).colorScheme.onBackground,
              fontSize: 12.sp,
              fontWeight: FontWeight.w400)),
    );
  }

  Widget _primaryDivider(BuildContext context) {
    return Divider(
      height: 12.3.h,
      color: Theme.of(context).colorScheme.onBackground.withOpacity(0.2),
    );
  }
}
