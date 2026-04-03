// ignore_for_file: deprecated_member_use, must_be_immutable
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/constants/app_colors.dart';
import '../../languages/l10n/generated/app_localizations.dart';
import '../custom_text_styles.dart';

class BlockUserDiolog extends StatelessWidget {
  const BlockUserDiolog({super.key, required this.onPressed,required this.isUserBlock});

  final VoidCallback? onPressed;
  final bool? isUserBlock;

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
          Text(isUserBlock == true ? 'Unblock User' : 'Block User', style: CustomTextStyles.appBarTitleText(context)),
          SizedBox(height: 8.h),
          Text(
            isUserBlock == true ?
            'Are you sure you want to unblock this user?' : 
            'Are you sure you want to block this user?',
            style: CustomTextStyles.lblPrimaryText(context),
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
                  isUserBlock == true ?
                  'UNBLOCK' : 'BLOCK',
                  style: TextStyle(
                    fontSize: 12.sp,
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
