// ignore_for_file: deprecated_member_use, must_be_immutable
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/constants/app_colors.dart';
import '../../../l10n/generated/app_localizations.dart';

class DeleteGroupDiolog extends StatelessWidget {
  const DeleteGroupDiolog({super.key, required this.onPressed});

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
            'Delete Group',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onBackground,
              fontSize: 11.3.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'Are you sure you want to delete this group?',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onBackground,
              fontSize: 11.sp,
              fontWeight: FontWeight.w400,
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
                  style: TextStyle(
                    fontSize: 11.5.sp,
                    color: Theme.of(context).colorScheme.onBackground,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              SizedBox(width: 15.w),
              GestureDetector(
                onTap: onPressed,
                child: Text(
                  'DELETE',
                  style: TextStyle(
                    fontSize: 11.5.sp,
                    color: AppColors.redColor,
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
