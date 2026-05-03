// ignore_for_file: deprecated_member_use, must_be_immutable
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../languages/l10n/generated/app_localizations.dart';
import '../../core/themes/app_text_styles.dart';

class LogoutDialog extends StatelessWidget {
  const LogoutDialog({super.key, required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 325,
      padding: EdgeInsets.fromLTRB(15.w, 12.h, 15.w, 12.h),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            AppLocalizations.of(context)!.logout,
            style: AppTextStyles.pageTitleTextStyle(
              context,
            ).copyWith(fontSize: 18, fontWeight: FontWeight.w500),
          ),
          SizedBox(height: 8.h),
          Text(
            AppLocalizations.of(context)!.areyousurewanttologout,
            style: AppTextStyles.bodyText.copyWith(
              color: Theme.of(context).colorScheme.onBackground,
            ),
          ),
          SizedBox(height: 10.h),
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
                  AppLocalizations.of(context)!.logout.toUpperCase(),
                  style: AppTextStyles.subText.copyWith(
                    fontSize: 12.sp,
                    color: Theme.of(context).colorScheme.error,
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
