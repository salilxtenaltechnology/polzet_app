// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_radius.dart';
import '../../../core/themes/app_text_styles.dart';
import '../../../languages/l10n/generated/app_localizations.dart';

class SwithBusinessAccDiolog extends StatelessWidget {
  const SwithBusinessAccDiolog({super.key, required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 325,
      height: 202.h,
      padding: EdgeInsets.fromLTRB(15.w, 12.h, 15.w, 12.h),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: AppRadius.cardRadius,
      ),
      child: Column(
        children: [
          Icon(Icons.auto_graph, color: AppColors.primaryColor, size: 32.sp),
          SizedBox(height: 10.h),
          Text(
            AppLocalizations.of(context)!.upgradetobusinessaccount,
            style: AppTextStyles.subText.copyWith(
              color: Theme.of(context).colorScheme.onBackground,
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 10.h),
          Text(
            AppLocalizations.of(context)!.youareabouttounlockpowerfull,
            style: AppTextStyles.subText.copyWith(
              color: Theme.of(context).colorScheme.onBackground,
              fontSize: 11.2.sp,
              fontWeight: FontWeight.w400,
            ),
          ),
          SizedBox(height: 7.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Text(
                AppLocalizations.of(context)!.morefunctionalitywillbesoon,
                style: AppTextStyles.subText.copyWith(
                  color: Theme.of(context).colorScheme.onBackground,
                  fontSize: 11.2.sp,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Text(
                  AppLocalizations.of(context)!.close.toUpperCase(),
                  style: AppTextStyles.subText.copyWith(
                    fontSize: 12.sp,
                    color: Theme.of(context).colorScheme.onBackground,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              SizedBox(width: 15.w),
              GestureDetector(
                onTap: onPressed,
                child: Text(
                  AppLocalizations.of(context)!.upgrade,
                  style: AppTextStyles.subText.copyWith(
                    fontSize: 12.sp,
                    color: AppColors.primaryColor,
                    fontWeight: FontWeight.w500,
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
