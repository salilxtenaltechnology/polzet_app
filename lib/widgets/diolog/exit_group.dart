// ignore_for_file: deprecated_member_use, must_be_immutable
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/constants/app_images.dart';
import '../custom_text_styles.dart';

class ExitGroupDiolog extends StatelessWidget {
  const ExitGroupDiolog({super.key, required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 315,
      padding: EdgeInsets.fromLTRB(15.w, 13.h, 15.w, 13.h),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(Assets.assetsImagesIcLogout, width: 50.w, height: 50.h),
          SizedBox(height: 15.h),
          Text(
            'Exit “Food” Group?',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onBackground,
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 12.h),
          Text(
            'Only group admins will be notified that you left the group.',
            textAlign: TextAlign.center,
            style: CustomTextStyles.lblPrimaryText(context),
          ),
          SizedBox(height: 15.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width: 110.w,
                  height: 30.h,
                  decoration: BoxDecoration(
                    color: const Color(0XFFC8FEC5),
                    borderRadius: BorderRadius.circular(5.r),
                  ),
                  child: Center(
                    child: Text(
                      'Archive instead',
                      style: TextStyle(
                        color: const Color(0XFF0A9C03),
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
              Container(
                width: 110.w,
                height: 30.h,
                decoration: BoxDecoration(
                  color: const Color(0XFFFFEAEA),
                  borderRadius: BorderRadius.circular(5.r),
                ),
                child: Center(
                  child: Text(
                    'Exit group',
                    style: TextStyle(
                      color: const Color(0XFFDE0004),
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
