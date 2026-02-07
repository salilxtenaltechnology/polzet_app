import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../../core/constants/app_images.dart';

Widget statTile(IconData icon, String value, VoidCallback onTap) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      color: Colors.transparent,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Image.asset(
                Assets.assetsImagesCurrentUser,
                height: 18.5.h,
                width: 18.5.w,
              ),
              SizedBox(height: 2.h),
              Icon(icon, size: 20.spMax, color: Colors.white.withOpacity(0.8)),
              SizedBox(height: 2.h),
              Image.asset(
                Assets.assetsImagesAddUsers,
                height: 18.5.h,
                width: 18.5.w,
              ),
            ],
          ),
          SizedBox(width: 5.h),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: 14.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    ),
  );
}

Widget pollThingsTile(String icon, String value, VoidCallback onTap) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      color: Colors.transparent,
      width: 55.w,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(icon, height: 16.h, width: 16.w),
          SizedBox(height: 2.h),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: 12.5.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    ),
  );
}
