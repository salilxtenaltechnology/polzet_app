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
      width: 330,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: AppRadius.cardRadius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: 12.h),
          Icon(Icons.auto_graph, color: AppColors.primaryColor, size: 32.sp),

          Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context)!.upgradetobusinessaccount,
                  style: AppTextStyles.cardTitle.copyWith(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onBackground,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  AppLocalizations.of(context)!.youareabouttounlockpowerfull,
                  style: AppTextStyles.bodyText.copyWith(
                    color: Theme.of(context).colorScheme.onBackground,
                    fontSize: 12.sp,
                  ),
                ),
                SizedBox(height: 10.h),
                Text(
                  AppLocalizations.of(context)!.morefunctionalitywillbesoon,
                  style: AppTextStyles.bodyText.copyWith(
                    color: Theme.of(context).colorScheme.onBackground,
                    fontSize: 12.sp,
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, thickness: 1, color: Color(0XFFDCDCDC)),
          IntrinsicHeight(
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: 10.h),
                      decoration: const BoxDecoration(
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(20),
                        ),
                      ),
                      child: Text(
                        AppLocalizations.of(context)!.cancel,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.subText.copyWith(
                          fontSize: 13.5.sp,
                          color: const Color(0XFF898989),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                ),

                const VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: Color(0XFFDCDCDC),
                ),

                Expanded(
                  child: GestureDetector(
                    onTap: onPressed,
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: 10.h),
                      decoration: const BoxDecoration(
                        borderRadius: BorderRadius.only(
                          bottomRight: Radius.circular(20),
                        ),
                      ),
                      child: Text(
                        AppLocalizations.of(context)!.upgrade.toUpperCase(),
                        textAlign: TextAlign.center,
                        style: AppTextStyles.subText.copyWith(
                          fontSize: 13.5.sp,
                          color: AppColors.primaryColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Row(
          //   mainAxisAlignment: MainAxisAlignment.end,
          //   children: [
          //     GestureDetector(
          //       onTap: () => Navigator.of(context).pop(),
          //       child: Text(
          //         AppLocalizations.of(context)!.close.toUpperCase(),
          //         style: AppTextStyles.subText.copyWith(
          //           fontSize: 12.sp,
          //           color: Theme.of(context).colorScheme.onBackground,
          //           fontWeight: FontWeight.w500,
          //         ),
          //       ),
          //     ),
          //     SizedBox(width: 15.w),
          //     GestureDetector(
          //       onTap: onPressed,
          //       child: Text(
          //         AppLocalizations.of(context)!.upgrade,
          //         style: AppTextStyles.subText.copyWith(
          //           fontSize: 12.sp,
          //           color: AppColors.primaryColor,
          //           fontWeight: FontWeight.w500,
          //         ),
          //       ),
          //     ),
          //   ],
          // ),
        ],
      ),
    );
  }
}
